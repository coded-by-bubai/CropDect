import json
import os

notebook = {
    "cells": [
        {
            "cell_type": "markdown",
            "metadata": {},
            "source": [
                "# Crop Disease AI Model Training (PlantVillage)\n",
                "This notebook automatically downloads the Kaggle PlantVillage dataset and trains a MobileNetV2 PyTorch model."
            ]
        },
        {
            "cell_type": "code",
            "metadata": {},
            "execution_count": None,
            "outputs": [],
            "source": [
                "!pip install kaggle\n",
                "import os\n",
                "# You will need your Kaggle API token (kaggle.json)\n",
                "# Upload it here before running the next cell\n",
                "from google.colab import files\n",
                "files.upload()"
            ]
        },
        {
            "cell_type": "code",
            "metadata": {},
            "execution_count": None,
            "outputs": [],
            "source": [
                "!mkdir -p ~/.kaggle\n",
                "!cp kaggle.json ~/.kaggle/\n",
                "!chmod 600 ~/.kaggle/kaggle.json\n",
                "!kaggle datasets download -d abdallahalidev/plantvillage-dataset\n",
                "!unzip -q plantvillage-dataset.zip -d dataset"
            ]
        },
        {
            "cell_type": "code",
            "metadata": {},
            "execution_count": None,
            "outputs": [],
            "source": [
                "import torch\n",
                "import torch.nn as nn\n",
                "import torch.optim as optim\n",
                "from torchvision import datasets, models, transforms\n",
                "from torch.utils.data import DataLoader\n",
                "import os\n",
                "\n",
                "device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')\n",
                "print(f'Using device: {device}')"
            ]
        },
        {
            "cell_type": "code",
            "metadata": {},
            "execution_count": None,
            "outputs": [],
            "source": [
                "data_dir = 'dataset/plantvillage dataset/color'\n",
                "transform = transforms.Compose([\n",
                "    transforms.Resize((224, 224)),\n",
                "    transforms.ToTensor(),\n",
                "    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])\n",
                "])\n",
                "dataset = datasets.ImageFolder(data_dir, transform=transform)\n",
                "dataloader = DataLoader(dataset, batch_size=32, shuffle=True)\n",
                "print(f'Found {len(dataset)} images belonging to {len(dataset.classes)} classes.')"
            ]
        },
        {
            "cell_type": "code",
            "metadata": {},
            "execution_count": None,
            "outputs": [],
            "source": [
                "model = models.mobilenet_v2(pretrained=True)\n",
                "model.classifier[1] = nn.Linear(model.last_channel, len(dataset.classes))\n",
                "model = model.to(device)\n",
                "\n",
                "criterion = nn.CrossEntropyLoss()\n",
                "optimizer = optim.Adam(model.parameters(), lr=0.001)\n",
                "\n",
                "print('Starting training for 5 epochs...')\n",
                "for epoch in range(5):\n",
                "    model.train()\n",
                "    running_loss = 0.0\n",
                "    for inputs, labels in dataloader:\n",
                "        inputs, labels = inputs.to(device), labels.to(device)\n",
                "        optimizer.zero_grad()\n",
                "        outputs = model(inputs)\n",
                "        loss = criterion(outputs, labels)\n",
                "        loss.backward()\n",
                "        optimizer.step()\n",
                "        running_loss += loss.item()\n",
                "    print(f'Epoch {epoch+1}/5 - Loss: {running_loss/len(dataloader):.4f}')\n",
                "\n",
                "torch.save(model.state_dict(), 'model.pt')\n",
                "print('Model saved as model.pt! Download this file.')"
            ]
        }
    ],
    "metadata": {
        "kernelspec": {
            "display_name": "Python 3",
            "language": "python",
            "name": "python3"
        }
    },
    "nbformat": 4,
    "nbformat_minor": 4
}

os.makedirs('ml', exist_ok=True)
with open('ml/train_model.ipynb', 'w') as f:
    json.dump(notebook, f, indent=2)
