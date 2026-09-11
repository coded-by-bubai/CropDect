import os
import time
import copy
import torch
import torch.nn as nn
import torch.optim as optim
from torch.optim import lr_scheduler
from torchvision import datasets, models, transforms
from torch.utils.data import DataLoader, SubsetRandomSampler
from sklearn.model_selection import StratifiedKFold
import numpy as np

import glob
import os

# ---------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------
# Dynamically find the 'color' directory in the Kaggle input
try:
    DATA_DIR = glob.glob('/kaggle/input/**/color', recursive=True)[0]
except IndexError:
    DATA_DIR = '/kaggle/input/plantvillage-dataset/plantvillage dataset/color'

NUM_EPOCHS = 15
BATCH_SIZE = 32
K_FOLDS = 5
LEARNING_RATE = 0.001
NUM_CLASSES = 38
DEVICE = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")

# ---------------------------------------------------------
# DATA AUGMENTATION (Crucial for "Outside Data")
# ---------------------------------------------------------
# We use heavy augmentation so the model stops relying on the clean PlantVillage background
data_transforms = {
    'train': transforms.Compose([
        transforms.RandomResizedCrop(224, scale=(0.6, 1.0)), # Simulates extreme closeups
        transforms.RandomHorizontalFlip(),
        transforms.RandomVerticalFlip(),
        transforms.RandomRotation(45),
        transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3, hue=0.1), # Simulates outdoor lighting
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ]),
    'val': transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ]),
}

# ---------------------------------------------------------
# MAIN TRAINING LOGIC
# ---------------------------------------------------------
def train_model():
    print(f"Using device: {DEVICE}")
    
    # Load entire dataset
    full_dataset = datasets.ImageFolder(DATA_DIR)
    targets = full_dataset.targets
    
    print(f"Loaded {len(full_dataset)} images from {DATA_DIR}.")
    print(f"Classes: {full_dataset.classes}")
    
    # Initialize Stratified K-Fold
    skf = StratifiedKFold(n_splits=K_FOLDS, shuffle=True, random_state=42)
    
    best_overall_acc = 0.0
    best_model_wts = None
    
    # Cross Validation Loop
    for fold, (train_idx, val_idx) in enumerate(skf.split(np.zeros(len(targets)), targets)):
        print(f"\n{'-'*30}")
        print(f"FOLD {fold+1}/{K_FOLDS}")
        print(f"{'-'*30}")
        
        # Define samplers
        train_subsampler = SubsetRandomSampler(train_idx)
        val_subsampler = SubsetRandomSampler(val_idx)
        
        # We need to apply different transforms for train and val.
        # A trick is to create two dataset objects pointing to the same folder but with different transforms.
        train_dataset = datasets.ImageFolder(DATA_DIR, transform=data_transforms['train'])
        val_dataset = datasets.ImageFolder(DATA_DIR, transform=data_transforms['val'])
        
        dataloaders = {
            'train': DataLoader(train_dataset, batch_size=BATCH_SIZE, sampler=train_subsampler, num_workers=4, pin_memory=True),
            'val': DataLoader(val_dataset, batch_size=BATCH_SIZE, sampler=val_subsampler, num_workers=4, pin_memory=True)
        }
        dataset_sizes = {'train': len(train_idx), 'val': len(val_idx)}
        
        # Initialize EfficientNet-B0
        model = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT)
        # Freeze early layers to speed up training and prevent forgetting
        for param in list(model.parameters())[:-20]:
            param.requires_grad = False
            
        # Replace classifier
        num_ftrs = model.classifier[1].in_features
        model.classifier[1] = nn.Linear(num_ftrs, NUM_CLASSES)
        model = model.to(DEVICE)
        
        criterion = nn.CrossEntropyLoss()
        # AdamW is generally better than Adam for image classification
        optimizer = optim.AdamW(model.classifier.parameters(), lr=LEARNING_RATE, weight_decay=1e-4)
        # Cosine Annealing learning rate
        scheduler = lr_scheduler.CosineAnnealingLR(optimizer, T_max=NUM_EPOCHS)
        
        fold_best_acc = 0.0
        
        # Epoch Loop
        for epoch in range(NUM_EPOCHS):
            print(f"Epoch {epoch+1}/{NUM_EPOCHS}")
            
            for phase in ['train', 'val']:
                if phase == 'train':
                    model.train()
                else:
                    model.eval()
                    
                running_loss = 0.0
                running_corrects = 0
                
                for inputs, labels in dataloaders[phase]:
                    inputs = inputs.to(DEVICE)
                    labels = labels.to(DEVICE)
                    
                    optimizer.zero_grad()
                    
                    with torch.set_grad_enabled(phase == 'train'):
                        outputs = model(inputs)
                        _, preds = torch.max(outputs, 1)
                        loss = criterion(outputs, labels)
                        
                        if phase == 'train':
                            loss.backward()
                            optimizer.step()
                            
                    running_loss += loss.item() * inputs.size(0)
                    running_corrects += torch.sum(preds == labels.data)
                    
                if phase == 'train':
                    scheduler.step()
                    
                epoch_loss = running_loss / dataset_sizes[phase]
                epoch_acc = running_corrects.double() / dataset_sizes[phase]
                
                print(f"{phase.capitalize()} Loss: {epoch_loss:.4f} Acc: {epoch_acc:.4f}")
                
                # Save best model logic
                if phase == 'val' and epoch_acc > fold_best_acc:
                    fold_best_acc = epoch_acc
                    if fold_best_acc > best_overall_acc:
                        best_overall_acc = fold_best_acc
                        best_model_wts = copy.deepcopy(model.state_dict())
                        torch.save(best_model_wts, 'best_efficientnet_model.pt')
                        print(f"*** New Best Model Saved (Acc: {best_overall_acc:.4f}) ***")
        
        print(f"Best Fold {fold+1} Acc: {fold_best_acc:.4f}")
        
    print(f"\nTraining Complete. Best Overall Validation Accuracy: {best_overall_acc:.4f}")
    print("The best weights have been saved to 'best_efficientnet_model.pt'")

if __name__ == '__main__':
    train_model()
