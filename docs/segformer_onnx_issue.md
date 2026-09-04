# MATLAB ONNX Converter — broken protobuf dependency (SegFormer import blocker)

## Goal

Import a SegFormer-B0 model (exported from PyTorch to ONNX, opset 18)
into MATLAB via `importNetworkFromONNX`, to fine-tune it for
microaneurysm segmentation.

## Environment

- Windows 11
- MATLAB **R2025a** and **R2025b** — both tested, both fail identically
- Deep Learning Toolbox Converter for ONNX Model Format, identifier
  `ONNXCONVERTER`, version **25.1.1** (per `matlab.addons.installedAddons`)
- GPU: NVIDIA RTX 3060 Laptop — not relevant, failure happens before any GPU work

## The ONNX file itself is fine

Exported with `torch.onnx.export` (opset 18), validated with
`onnx.checker.check_model()` — passes. Confirmed shapes:
`image` input `[batch, 3, 512, 512]` → `logits` output `[batch, 2, 128, 128]`
(SegFormer's native 1/4-resolution output, as expected).

## The failure

`importNetworkFromONNX('segformer_ma.onnx', 'InputDataFormats','BCSS', 'OutputDataFormats','BCSS')`
fails inside MATLAB's own MEX layer, before it even reads the ONNX
file's contents:

```
Error using nnet.internal.cnn.onnx.onnxmex
Invalid MEX-file 'onnxmex.mexw64': The specified procedure could not be found.

Error in nnet.internal.cnn.onnx.ModelProto (line 40)
    ModelPtr = onnxmex(int32(FuncName.EdeserializeFromFile), filename);
```

(Before fixing a separate missing-DLL issue below, the error was
"The specified **module** could not be found" instead of "procedure" —
that's a distinct, already-resolved problem; see below.)

## Root cause, confirmed by direct binary inspection

Used Python's `pefile` to read `onnxmex.mexw64`'s import table and
cross-check every imported symbol against the actual export table of
each dependency DLL. One specific symbol is missing:

```
?element_at@RepeatedPtrFieldBase@internal@mathworks@protobuf@google@@AEBAPEBXH@Z
```
(demangles to `google::protobuf::mathworks::internal::RepeatedPtrFieldBase::element_at(int) const`)

This symbol is **absent from every `libprotobuf3.dll` on the system**,
checked in all three places it exists:

1. `C:\Program Files\MATLAB\R2025a\bin\win64\libprotobuf3.dll`
2. `C:\Program Files\MATLAB\R2025b\bin\win64\libprotobuf3.dll` (different MD5 from #1 — genuinely a different build, not a copy)
3. `C:\Program Files\MATLAB\R2025b\toolbox\compiler_sdk\mps_clients\c\win64\lib\libprotobuf3.dll`

`onnxmex.mexw64` (the ONNX converter's compiled core) expects this
symbol from whichever `libprotobuf3.dll` it resolves at load time —
which is always the base MATLAB install's copy, since the ONNX
converter support package **does not ship its own protobuf DLL**
(confirmed: no `libprotobuf3.dll` anywhere under the support package's
own installed folder tree).

## What's been ruled out

- **Not a corrupted install**: fully uninstalled (via Add-Ons → Manage
  Add-Ons) and reinstalled the ONNX converter — same error, byte-identical symptom.
- **Not a Windows DLL-search-path issue**: copying every dependency
  (`onnxpb.dll`, `libprotobuf3.dll`, `abseil_dll.dll`, etc.) directly
  next to `onnxmex.mexw64` (highest-priority search location) changes
  the error from "module not found" to "procedure not found" — i.e.
  it fixes DLL *discovery* but exposes the real problem underneath:
  the DLL is found, but the specific function isn't in it.
- **Not a MATLAB-version issue**: tested on a completely fresh R2025b
  install (installed same night specifically to test this) with the
  ONNX converter reinstalled fresh there too, using **only R2025b's
  own native files** (not mixed with R2025a). Identical failure,
  identical missing symbol.
- **Not an "old MATLAB, new package" mismatch**: even the *separately
  distributed* Compiler SDK's own `libprotobuf3.dll` (a third,
  independent copy) doesn't have the symbol either.

## Conclusion

This looks like a genuine packaging defect in the "Deep Learning
Toolbox Converter for ONNX Model Format" v25.1.1 as currently
distributed by MathWorks: `onnxmex.mexw64` was compiled against a
newer/different build of MathWorks' internal protobuf fork than what
ships in *either* R2025a's or R2025b's base MATLAB install. Not
something fixable by reinstalling, updating MATLAB, or DLL patching
without the correct matching `libprotobuf3.dll` — which doesn't appear
to be distributed anywhere accessible.

## Fallback in place

A MATLAB-native CBAM-attention CNN (no ONNX, no Python at inference
time) exists as a verified-working substitute:
`module2_segmentation/trackB_microaneurysms/buildTrackBNetwork.m`.
Not currently used, pending a decision on whether to keep chasing the
ONNX path (e.g. via MathWorks support) or switch to it.
