from pathlib import Path

import numpy as np
from python.runfiles import Runfiles

r = Runfiles.Create()

hello_txt_path = Path(r.Rlocation("rules_rsync/test/hello.txt"))

print("Hello from Python!")
print("Checking if numpy is working...", end="")
assert np.all(np.ones((11, 12)) * 2 == 2)
print("✅")

assert hello_txt_path.exists()
with open(hello_txt_path, "rt") as f:
    print("test/hello.txt:")
    print(f.read(), end="")
