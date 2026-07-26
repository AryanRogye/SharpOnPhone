import time
from pathlib import Path

import torch
from coreai.runtime import AIModelAssetMetadata
from coreai_torch import TorchConverter, get_decomp_table
from sharp.models import PredictorParams, create_predictor

# 1. Load the PyTorch weight checkpoint you have. Resolve it from this script's
# directory so `uv run ... python convert_sharp.py` works from any cwd.
project_root = Path(__file__).resolve().parent
checkpoint_path = project_root / "sharp_2572gikvuh.pt"
if not checkpoint_path.is_file():
    raise FileNotFoundError(
        f"Missing SHARP checkpoint: {checkpoint_path}\n"
        "Download it with:\n"
        "  curl -L https://ml-site.cdn-apple.com/models/sharp/"
        "sharp_2572gikvuh.pt -o sharp_2572gikvuh.pt"
    )

# 1. Define the model parameters (leave empty for default configuration)
params = PredictorParams()

# 2. Instantiate the model using the predictor factory function.
# Keep the export model and reference tensors on CPU; Core AI's converter traces
# the PyTorch graph and does not need MPS/CUDA execution here.
model = create_predictor(params).to("cpu")
model.load_state_dict(torch.load(checkpoint_path, map_location="cpu"))
# ANE model I/O is FP16.  Cast the weights before torch.export so the
# exported graph does not acquire FP32 parameters from the checkpoint.
model = model.half().eval()

class SharpExportModule(torch.nn.Module):
    """Expose Sharp's NamedTuple result as plain tensor outputs for Core AI."""

    def __init__(self, predictor: torch.nn.Module):
        super().__init__()
        self.predictor = predictor

    def forward(self, image: torch.Tensor, disparity_factor: torch.Tensor):
        gaussians = self.predictor(image, disparity_factor)
        return (
            # Keep the public Core AI interface in standard FP16 even when a
            # numerically-stable internal operation temporarily uses FP32.
            gaussians.mean_vectors.to(torch.float16),
            gaussians.singular_values.to(torch.float16),
            gaussians.quaternions.to(torch.float16),
            gaussians.colors.to(torch.float16),
            gaussians.opacities.to(torch.float16),
        )


# Sharp's inference path resizes images to 1536x1536 before prediction.
# Start with that fixed shape so the exported graph matches the reference model.
dummy_image = torch.rand(1, 3, 1536, 1536, dtype=torch.float16)
dummy_disparity_factor = torch.ones(1, dtype=torch.float16)
export_model = SharpExportModule(model).eval()

# 3. Export to Core AI format
print("Converting SHARP to Apple Core AI format...")
previous_default_dtype = torch.get_default_dtype()
torch.set_default_dtype(torch.float16)
try:
    with torch.no_grad():
        exported = torch.export.export(
            export_model,
            args=(dummy_image, dummy_disparity_factor),
        )
    # Decomposition can re-materialize scalar constants, so it must see the
    # same FP16 default dtype as the initial export.
    exported = exported.run_decompositions(get_decomp_table())
finally:
    torch.set_default_dtype(previous_default_dtype)

program = TorchConverter().add_exported_program(
    exported_program=exported,
    input_names=["image", "disparity_factor"],
    output_names=[
        "mean_vectors",
        "singular_values",
        "quaternions",
        "colors",
        "opacities",
    ],
).to_coreai()
program.optimize()

output_path = project_root / "sharp_model.aimodel"
metadata = AIModelAssetMetadata()
metadata.author = "Apple SHARP authors"
metadata.license = "See ml-sharp/LICENSE_MODEL"
metadata.model_description = "SHARP monocular view synthesis neural network exported to Core AI."
metadata.creation_date = int(time.time())
program.save_asset(output_path, metadata)

print(f"Success! {output_path} created.")
