"""Constant values."""
from pathlib import Path

DEFAULT_S3_BUCKET = "shared-ssm-dox-dev"
PROJECT_ROOT = Path(__file__).parent.parent
RAW_DOX = PROJECT_ROOT / "dox"
SHARED_SSM_DOCS = PROJECT_ROOT / "shared_ssm_docs"
