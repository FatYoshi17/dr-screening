"""
exportSegformerTorchExport.py - Export SegFormer as a PyTorch ExportedProgram
for MATLAB's importNetworkFromPyTorch (a separate, protobuf-free import path
from the broken ONNX converter - see docs/segformer_onnx_issue.md).

MathWorks' docs for importNetworkFromPyTorch explicitly recommend
torch.export.export() over torch.jit.trace() and state ExportedProgram
support targets PyTorch 2.8 specifically - use that exact version, not
whatever pip installs by default (traced models silently work "in
other versions" per the docs, but ExportedProgram is the documented,
supported path).

    pip install "torch==2.8.0" transformers

Usage:
    python exportSegformerTorchExport.py --patch_size 512 --num_classes 2 --out segformer_ma.pt2
"""
import argparse
import torch
import torch.nn as nn
from transformers import SegformerForSemanticSegmentation, SegformerConfig


class SegformerLogitsOnly(nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, pixel_values):
        return self.model(pixel_values=pixel_values).logits


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--patch_size', type=int, default=512)
    parser.add_argument('--num_classes', type=int, default=2)
    parser.add_argument('--pretrained', type=str,
                         default='nvidia/segformer-b0-finetuned-ade-512-512')
    parser.add_argument('--out', type=str, default='segformer_ma.pt2')
    args = parser.parse_args()

    print(f'torch version: {torch.__version__}')

    config = SegformerConfig.from_pretrained(args.pretrained)
    config.num_labels = args.num_classes
    model = SegformerForSemanticSegmentation.from_pretrained(
        args.pretrained, config=config, ignore_mismatched_sizes=True)
    model.eval()

    wrapped = SegformerLogitsOnly(model)
    wrapped.eval()

    dummy_input = torch.randn(1, 3, args.patch_size, args.patch_size)

    with torch.no_grad():
        exported_program = torch.export.export(wrapped, (dummy_input,))
        torch.export.save(exported_program, args.out)

    print(f'Exported SegFormer-B0 ({args.num_classes}-class head, '
          f'{args.patch_size}x{args.patch_size} input) to {args.out}')

    # Sanity check: reload and run
    reloaded = torch.export.load(args.out)
    with torch.no_grad():
        out = reloaded.module()(dummy_input)
    print(f'Reload check OK. Output shape: {tuple(out.shape)}')


if __name__ == '__main__':
    main()
