import torch
import torch.nn as nn
from transformers import SegformerForSemanticSegmentation, SegformerConfig

print(f'torch version: {torch.__version__}')

class SegformerLogitsOnly(nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
    def forward(self, pixel_values):
        return self.model(pixel_values=pixel_values).logits

config = SegformerConfig.from_pretrained('nvidia/segformer-b0-finetuned-ade-512-512')
config.num_labels = 2
model = SegformerForSemanticSegmentation.from_pretrained(
    'nvidia/segformer-b0-finetuned-ade-512-512', config=config, ignore_mismatched_sizes=True)
model.eval()
wrapped = SegformerLogitsOnly(model)
wrapped.eval()

dummy_input = torch.randn(1, 3, 512, 512)
with torch.no_grad():
    traced = torch.jit.trace(wrapped, dummy_input)
    traced.save('C:/Users/Kartik/OneDrive/Desktop/projects/Blockers/dr-screening/data/models/segformer_ma_traced28.pt')

reloaded = torch.jit.load('C:/Users/Kartik/OneDrive/Desktop/projects/Blockers/dr-screening/data/models/segformer_ma_traced28.pt')
with torch.no_grad():
    out = reloaded(dummy_input)
print(f'Reload check OK. Output shape: {tuple(out.shape)}')
