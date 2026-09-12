# Firmware bridge

Ubuntu's `qcom`, `qca`, and `ath12k` trees are copied intact under `/usr/lib/firmware/7.0.0-31-generic/` in package release 2. Linux's version-specific firmware search is intended to keep this stack ahead of the general Arch firmware without replacing files owned by Arch packages. Matching namespace priority must be checked on the booted kernel. The package carries copyright/license texts from the source image. This prototype includes a broad Qualcomm set for early validation; refine against target requests once hardware is available.

Signed kernel artifacts, module firmware requests and original relative links are preserved. Compression is not rewritten. Broader dock firmware can still come from Arch packages. Nothing requires Windows firmware extraction.
