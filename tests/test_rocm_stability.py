import importlib
import os
import shutil
import sys
import tempfile
import types
import unittest

sys.modules.setdefault("httpx", types.SimpleNamespace())
sys.modules.setdefault(
    "magic",
    types.SimpleNamespace(
        from_file=lambda *args, **kwargs: "application/pdf",
        from_buffer=lambda *args, **kwargs: "application/pdf",
    ),
)


class _HTTPException(Exception):
    def __init__(self, status_code: int, detail: str):
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail


class _FastAPI:
    def __init__(self, *args, **kwargs):
        pass

    def get(self, *args, **kwargs):
        return lambda fn: fn

    def post(self, *args, **kwargs):
        return lambda fn: fn

    def delete(self, *args, **kwargs):
        return lambda fn: fn

    def on_event(self, *args, **kwargs):
        return lambda fn: fn


class _BackgroundTasks:
    def add_task(self, fn, *args, **kwargs):
        return fn(*args, **kwargs)


def _Query(default=None, **kwargs):
    return default


class _BaseModel:
    def __init__(self, **kwargs):
        for key, value in kwargs.items():
            setattr(self, key, value)

    def model_dump(self):
        return self.__dict__.copy()


sys.modules.setdefault(
    "fastapi",
    types.SimpleNamespace(
        BackgroundTasks=_BackgroundTasks,
        FastAPI=_FastAPI,
        HTTPException=_HTTPException,
        Query=_Query,
    ),
)
sys.modules.setdefault("pydantic", types.SimpleNamespace(BaseModel=_BaseModel))


class RocmStabilityTests(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp(prefix="parser-monstro-rocm-")
        os.environ["STORAGE_ROOT"] = self.tmpdir
        os.environ["ENABLE_EASYOCR"] = "true"
        os.environ.pop("PYTORCH_CUDA_ALLOC_CONF", None)
        os.environ.pop("HIPBLAS_WORKSPACE_CONFIG", None)
        sys.modules.pop("main", None)
        import main  # noqa: F401
        self.main = importlib.import_module("main")

    def tearDown(self):
        sys.modules.pop("main", None)
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_rocm_allocator_defaults_are_applied(self):
        self.assertEqual(os.environ["PYTORCH_CUDA_ALLOC_CONF"], "expandable_segments:True")
        self.assertEqual(os.environ["HIPBLAS_WORKSPACE_CONFIG"], ":4096:8")

    def test_health_reports_easyocr_disabled_even_if_env_requests_it(self):
        payload = self.main.health()

        self.assertFalse(payload["easyocr_enabled"])
        self.assertIn("temporariamente desabilitado", payload["easyocr_disabled_reason"])

    def test_effective_easyocr_is_always_disabled(self):
        self.assertFalse(self.main._effective_easyocr_enabled(True))
        self.assertFalse(self.main._effective_easyocr_enabled(False))


if __name__ == "__main__":
    unittest.main()
