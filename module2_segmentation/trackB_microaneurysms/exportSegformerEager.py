"""
exportSegformerEager.py - Export SegFormer to a torch.jit.trace .pt file
that MATLAB's importNetworkFromPyTorch can actually load.

Background: MATLAB R2025b's "Deep Learning Toolbox Converter for PyTorch
Model Format" (v25.2.2) requires a torch.jit.trace()-produced .pt file -
NOT the newer torch.export.export()/.pt2 ExportedProgram format that
MathWorks' general docs describe as recommended (confirmed by the
importer's own error message: "must be a valid PyTorch model (*.pt)
traced using 'torch.jit.trace'"). This supersedes the ONNX export path
(exportSegformerONNX.py / docs/segformer_onnx_issue.md) which is blocked
by a genuine packaging defect in MathWorks' ONNX converter (a missing
protobuf symbol present in every copy of libprotobuf3.dll across
R2025a, a fresh R2025b install, and the Compiler SDK).

Two things are required for torch.jit.trace to succeed on SegFormer's
attention modules:
  1. attn_implementation='eager' - the default scaled_dot_product_attention
     path contains a data-dependent Python bool
     (`is_causal = q_length > 1 and attention_mask is None and is_causal`
     in transformers' sdpa_attention.py) that the tracer cannot handle.
  2. PyTorch >= 2.8 (tested with 2.8.0+cpu) - the exact traced-graph shape
     the importer later has to walk depends on tracer internals that
     shifted across PyTorch minor versions during earlier attempts.

Run this in the project's dedicated venv (see .venv-segformer/):
    pip install torch==2.8.0 transformers

Usage:
    python exportSegformerEager.py --patch_size 512 --num_classes 2 \
        --out ../../data/models/segformer_eager.pt

Output: a .pt file. Import it into MATLAB with importSegformerPyTorch.m,
which wraps importNetworkFromPyTorch and applies the same fixes already
baked into the +segformer_eager/ generated-code package in this repo.
"""
import argparse
import torch
from transformers import SegformerForSemanticSegmentation, SegformerConfig


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--patch_size', type=int, default=512,
                         help='Must match the patch size used in extractSlidingWindowPatches.m')
    parser.add_argument('--num_classes', type=int, default=2,
                         help='2 = binary MA/background dense prediction')
    parser.add_argument('--pretrained', type=str, default='nvidia/segformer-b0-finetuned-ade-512-512',
                         help='Starting checkpoint - b0 is the smallest SegFormer variant, '
                              'chosen deliberately to keep inference cost down since this still '
                              'has to run at district-tier server scale, not unlimited compute.')
    parser.add_argument('--out', type=str, default='segformer_eager.pt')
    args = parser.parse_args()

    # Same head swap as exportSegformerONNX.py: keep the pretrained Mix
    # Transformer encoder, replace the ADE20K 150-class head with our
    # 2-class (MA / not-MA) head, to be fine-tuned inside MATLAB.
    config = SegformerConfig.from_pretrained(args.pretrained)
    config.num_labels = args.num_classes
    model = SegformerForSemanticSegmentation.from_pretrained(
        args.pretrained, config=config, ignore_mismatched_sizes=True,
        attn_implementation='eager')
    model.eval()

    dummy_input = torch.randn(1, 3, args.patch_size, args.patch_size)

    traced = torch.jit.trace(model, dummy_input, strict=False)
    traced.save(args.out)

    print(f'Traced SegFormer-B0 ({args.num_classes}-class head, '
          f'{args.patch_size}x{args.patch_size} input) to {args.out}')
    print('Note: SegFormer output is at 1/4 resolution of the input '
          '(standard for this architecture) - importSegformerPyTorch.m '
          'upsamples back to full patch size after import.')


if __name__ == '__main__':
    main()
