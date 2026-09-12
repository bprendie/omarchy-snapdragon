# HP NPU validation — 2026-09-12

**A small QNN HTP graph executed successfully on the physical HP EliteBook
Ultra G1q.** This is a functional check, not an LLM or performance benchmark.
The runtime was staged separately for testing; it is not included in the
v0.1.0 installer ISO and is not configured as a permanent service.

Hardware/software: HP EliteBook Ultra G1q, kernel 7.0.0-31-generic, HP cDSP
firmware `CDSP.HT.2.9.c1-00046-HAMOA-1` already supplied by our HP firmware
package. No firmware replacement, DSP reset, boot change or driver reload was
needed. Tests ran as root because the current FastRPC device nodes are root-only.

Results:

- Qualcomm FastRPC calculator on domain 3 (cDSP): sum of 0–999 = **499500**;
  maximum = **999**. One test, one pass.
- QAIRT `qnn-platform-validator --backend dsp --testBackend`: hardware supported,
  libraries found, unit test passed. Its initial run failed only while saving
  results to its default path; the retry used an explicit local output directory.
- A four-element quantized ReLU graph used **HTP_QTI_AISW, backend ID 6**, loaded
  explicitly from `libQnnHtp.so`. Backend/device/context creation, graph
  preparation, execution and cleanup all returned zero. Input represented
  `[-2, -1, 0, 3]`; output represented **[0, 0, 0, 3]**, exactly as expected.
  The test did not load a QNN CPU backend or implement CPU fallback.

This establishes functional HTP backend execution for a small operation. It
makes no claim about matrix-unit utilization, model compatibility, speed,
energy efficiency, suspend/resume, or NPU operation on our other machines.

The first ReLU harness supplied client buffers too early, at tensor creation.
QNN rejected that setup and aborted during cleanup. The corrected harness
attaches buffers at execution; it passes and frees all QNN handles cleanly.
The HP remained reachable. Both successful tests used a temporary `cdsprpcd`
process that was stopped afterward; no service was enabled.

Inputs and attribution:

- [Qualcomm FastRPC](https://github.com/qualcomm/fastrpc): userspace RPC libraries,
  temporary listener daemon and calculator test. Built for ARM64 in our local
  Arch container with an isolated prefix under `~/npu-test/runtime`.
- HP SoftPaq sp162865: matching cDSP shells, C++ libraries and version library,
  from the same driver package as the running cDSP firmware.
- Qualcomm QAIRT **2.48.0.260626**: the `lib-safe/aarch64-oe-linux-gcc11.2` HTP
  backend and V73 DSP libraries, downloaded from Qualcomm's public SDK endpoint.
- Qualcomm Hexagon SDK **6.4.0.2**, tools **19.0.04**: V73 PIC `libc.so` and
  `libgcc.so`, extracted from Qualcomm's SDK archive.
- [T14s Linux NPU bring-up](https://github.com/UnsignedChad/t14s-x1e-npu): the
  matched-firmware and QNN runtime approach that informed this experiment.

Local evidence remains in ignored `build/hp-npu-audit/`: source revision,
firmware-file hashes, final C harness, build logs, `calculator.log`,
`qnn-validator-final.log`, and `htp-check-v2.log`. The test files remain on the
HP under `~/npu-test` for follow-up; proprietary SDK payloads were not added to
the GitHub source repository or the already-built ISO.
