# export_to_torchscript_lite.py  — works on new Torch (>=2.6) + new torchvision
import argparse, os, sys, torch, torchvision, torch.nn as nn
from torch.utils.mobile_optimizer import optimize_for_mobile
from torch.serialization import add_safe_globals, safe_globals

parser = argparse.ArgumentParser()
parser.add_argument("--ckpt", required=True, help="Path to ProtoSound .pt checkpoint")
parser.add_argument("--out",  default="protosound_model.ptl", help="Output TorchScript-Lite .ptl path")
# Your training DSP (from your earlier Python): 44.1 kHz, 2048/512, 128 mels => 83x128
parser.add_argument("--shape", default="1,1,83,128", help="B,C,T,M  (e.g., 1,1,83,128)")
# Only needed if the checkpoint is a pure state_dict
parser.add_argument("--model-module", default="", help="e.g., models.protosound")
parser.add_argument("--model-class",  default="", help="e.g., ProtoSoundModel")
args = parser.parse_args()

B,C,T,M = map(int, args.shape.split(","))

# --- 1) Shim older torchvision symbols so unpickler can resolve them ---
import torchvision.models.mobilenet as mobilenet_mod

# Older checkpoints reference ConvBNReLU and InvertedResidual by name
# New torchvision has ConvBNActivation; keep both.
if not hasattr(mobilenet_mod, "ConvBNReLU"):
    class ConvBNReLU(nn.Sequential):
        def __init__(self, in_planes, out_planes, kernel_size=3, stride=1, groups=1, norm_layer=None):
            padding = (kernel_size - 1) // 2
            if norm_layer is None:
                norm_layer = nn.BatchNorm2d
            super().__init__(
                nn.Conv2d(in_planes, out_planes, kernel_size, stride, padding, groups, bias=False),
                norm_layer(out_planes),
                nn.ReLU6(inplace=True),
            )
    setattr(mobilenet_mod, "ConvBNReLU", ConvBNReLU)

# Ensure InvertedResidual symbol is present on the module (it is in modern tv, but be explicit)
try:
    from torchvision.models.mobilenet import InvertedResidual
except Exception:
    class InvertedResidual(nn.Module):
        def __init__(self, *a, **kw): super().__init__()
        def forward(self, x): return x
    setattr(mobilenet_mod, "InvertedResidual", InvertedResidual)

# Allow-list the types the checkpoint references (so weights_only=True can be safe)
try:
    from torchvision.models.mobilenet import MobileNetV2, ConvBNActivation
    add_safe_globals([MobileNetV2, mobilenet_mod.InvertedResidual, ConvBNActivation, mobilenet_mod.ConvBNReLU])
except Exception:
    # Fallback: allow whatever we have
    try:
        from torchvision.models.mobilenet import MobileNetV2
        add_safe_globals([MobileNetV2, mobilenet_mod.InvertedResidual, mobilenet_mod.ConvBNReLU])
    except Exception:
        pass

# --- 2) Load the checkpoint safely; if that still fails, do a trusted load ---
def load_ckpt(path: str):
    # Try safe mode with allow-list
    try:
        print("[info] loading with weights_only=True (safe)…")
        with safe_globals([mobilenet_mod.ConvBNReLU, getattr(mobilenet_mod, "InvertedResidual")]):
            return torch.load(path, map_location="cpu", weights_only=True)
    except Exception as e:
        print("[warn] safe load failed:", e)
        print("[info] falling back to weights_only=False (ONLY if you trust this file)")
        # At this point we’ve injected the missing symbols, so legacy load should work.
        return torch.load(path, map_location="cpu", weights_only=False)

m = load_ckpt(args.ckpt)

def is_scripted(x): return isinstance(x, (torch.jit.ScriptModule, torch.jit.RecursiveScriptModule))

# --- 3) Turn it into a TorchScript module ---
if is_scripted(m):
    scripted = m.eval()
elif isinstance(m, dict):
    # state_dict path: need model class to instantiate
    if not args.model_module or not args.model_class:
        print("ERROR: Checkpoint is a state_dict. Provide --model-module and --model-class.")
        sys.exit(1)
    mod = __import__(args.model_module, fromlist=[args.model_class])
    Model = getattr(mod, args.model_class)
    model = Model()
    model.load_state_dict(m)
    model.eval()
    example = torch.randn(B, C, T, M)
    try:
        scripted = torch.jit.script(model)
    except Exception as e:
        print("[warn] scripting failed:", e, "→ tracing")
        scripted = torch.jit.trace(model, example)
else:
    # Full nn.Module reconstructed by torch.load
    model = m.eval()
    example = torch.randn(B, C, T, M)
    try:
        scripted = torch.jit.script(model)
    except Exception as e:
        print("[warn] scripting failed:", e, "→ tracing")
        scripted = torch.jit.trace(model, example)

# --- 4) Optimize + save for the Lite interpreter ---
scripted = torch.jit.optimize_for_inference(scripted)
scripted = optimize_for_mobile(scripted)
scripted._save_for_lite_interpreter(args.out)
print("[ok] saved:", os.path.abspath(args.out))
