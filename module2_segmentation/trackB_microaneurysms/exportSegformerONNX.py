"""
exportSegformerONNX.py - Export a SegFormer encoder-decoder to ONNX for MATLAB import.

Run this on a machine with Python + PyTorch + the `transformers` and
`onnx` packages installed (NOT inside this MATLAB-primary pipeline -
this is the one deliberate step outside MATLAB, per the Track B design
decision to use SegFormer here despite MATLAB's Deep Learning Toolbox
having no native SegFormer support).

    pip install torch transformers onnx

Usage:
    python exportSegformerONNX.py --patch_size 512 --num_classes 2 --out segformer_ma.onnx

num_classes=2 for binary MA/not-MA dense prediction (Track B only cares
about microaneurysm-vs-background per pixel within each sliding-window
patch - it is not a multi-class head like Track A's).

Output: an .onnx file. Import it into MATLAB with
importSegformerMATLAB.m, which wraps MATLAB's importNetworkFromONNX and
then fine-tunes on Refined IDRiD's MA channel.
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
    parser.add_argument('--out', type=str, default='segformer_ma.onnx')
    args = parser.parse_args()

    # Load pretrained SegFormer-B0 and swap its classification head to
    # our 2-class (MA / not-MA) output instead of its original ADE20K
    # 150-class head. The Mix Transformer encoder's ImageNet/ADE20K
    # pretraining is what we actually want to keep - the decoder head
    # gets replaced and will be fine-tuned from scratch on Refined IDRiD
    # inside MATLAB after import.
    config = SegformerConfig.from_pretrained(args.pretrained)
    config.num_labels = args.num_classes
    model = SegformerForSemanticSegmentation.from_pretrained(
        args.pretrained, config=config, ignore_mismatched_sizes=True)
    model.eval()

    dummy_input = torch.randn(1, 3, args.patch_size, args.patch_size)

    torch.onnx.export(
        model,
        dummy_input,
        args.out,
        input_names=['image'],
        output_names=['logits'],
        dynamic_axes={'image': {0: 'batch'}, 'logits': {0: 'batch'}},
        opset_version=17,
    )
    print(f'Exported SegFormer-B0 ({args.num_classes}-class head, '
          f'{args.patch_size}x{args.patch_size} input) to {args.out}')
    print('Note: SegFormer output is at 1/4 resolution of the input '
          '(standard for this architecture) - importSegformerMATLAB.m '
          'upsamples back to full patch size after import.')


if __name__ == '__main__':
    main()
