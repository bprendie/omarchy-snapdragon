# ThinkPad T14s follow-up — September 13, 2026

Target: ThinkPad T14s Gen 6, 21N10000US, BOE LCD, kernel
`7.0.0-31-generic`, Omarchy 4.0.3. The owner has disconnected the TrackPoint
cable and is awaiting a replacement keyboard. Keep that hardware condition
separate from conclusions about software support.

## Camera: missing userspace packages

The kernel already exposes the OV02C10 sensor and Qualcomm CAMSS media graph.
Its many `/dev/video*` nodes are ISP endpoints, not independent USB webcams.
The initial installation had no libcamera, IPA or PipeWire libcamera plugin.

Installed through `omarchy pkg add`:

```text
libcamera 0.7.2-4
libcamera-ipa 0.7.2-4                 (dependency)
libcamera-tools 0.7.2-4
pipewire-libcamera 1:1.6.8-1
gst-plugin-libcamera 0.7.2-4
```

After restarting the user's WirePlumber service, `wpctl status` exposes
**Built-in Front Camera**. These packages are now in `packages.extra` for the
next installer build; the published v0.1.0 ISO has not been rebuilt.

Validation on the physical ThinkPad:

- `cam -l` detects the internal front camera.
- `cam -c 1 --capture=10` completes ten frames without saving images.
- A bounded SDL preview produces a continuous stream around 30 fps; the owner
  confirmed the picture looked good.
- GStreamer captures ten frames through the PipeWire camera node into
  `fakesink`, exiting successfully. Use the node name, not a hardcoded numeric
  ID: an earlier numeric-target attempt returned `target not found`.

```bash
cam -l
cam -c 1 --capture=10
wpctl status
# Obtain the camera node.name from pw-dump; this is the name on this machine:
gst-launch-1.0 -q pipewiresrc \
  target-object=libcamera_input._base_soc_0_cci_ac16000_i2c-bus_1_camera_36 \
  num-buffers=10 ! video/x-raw ! fakesink
```

Libcamera still reports missing OV02C10 static properties, crop/rotation
controls and a sensor-specific tuning file. It falls back to uncalibrated
settings and uses the Adreno GPU for image processing. Frame delivery and a usable preview are
validated; calibrated color/exposure behavior, browser conferencing and suspend/resume
need separate checks. Browser applications may require their PipeWire camera
path rather than direct V4L2 access.

## Keyboard backlight: not yet fixed

Fn+Space produces Omarchy's backlight popup. The kernel registers
`platform::kbd_backlight` with maximum level 2 through `thinkpad-t14s-ec`.
A privileged `brightnessctl -d platform::kbd_backlight set 2` reports success,
but immediately reading the brightness attribute returns 0.

The popup is not proof that the light changed: Omarchy's command calculates
and displays the requested level. The observed result remains a driver/EC or
hardware investigation; it does not establish that the disconnected
TrackPoint cable is the cause. No EC register pokes, controller resets or
speculative driver replacements were performed.

The ordinary SSH session also lacks permission to set brightness directly;
that alone does not explain the privileged test's readback. Re-test with the
replacement keyboard before claiming this is a general T14s software defect.

## NPU: physically validated with a matched Lenovo firmware pair

All three checks passed on the ThinkPad:

- FastRPC calculator: sum **499500**, maximum **999**, one test passed.
- Qualcomm DSP platform validator: hardware supported, libraries found, unit
  test passed.
- The same four-element QNN HTP ReLU harness used on the HP: quantized input
  represents `[-2, -1, 0, 3]`, output is **[0, 0, 0, 3]**. Backend
  `HTP_QTI_AISW` (ID 6), graph execution and cleanup return zero. The harness
  explicitly loads `libQnnHtp.so`; no CPU fallback backend is loaded.

Unlike the HP, this required a temporary cDSP firmware change. The shipped
ThinkPad firmware is `CDSP.HT.2.9-00447-HAMOA-2`. We used Lenovo's own
`CDSP.HT.2.9.c1-00078-HAMOA-1` together with its matching shells and C++
libraries. This follows the branch-matching approach documented by the
[T14s NPU bring-up project](https://github.com/UnsignedChad/t14s-x1e-npu),
but uses a newly acquired Lenovo archive and our small existing test harness.

Acquisition and provenance:

- [Lenovo 21N1 Windows 11 catalog](https://download.lenovo.com/catalog/21N1_Win11.xml)
  identifies [n42qq23w metadata](https://download.lenovo.com/pccbbs/mobiles/n42qq23w_2_.xml).
- [n42qq23w.exe](https://download.lenovo.com/pccbbs/mobiles/n42qq23w.exe),
  package 1.0.0.23, September 1, 2026, 194,478,456 bytes.
- Archive SHA-256:
  `9ec6ae30abd40f56aa6b3b0b480686acbbb72ff12ba186b3f45f61fc924ef4f3`.
- Both the metadata hash in the HTTPS catalog and the archive hash/size in
  that metadata were checked. We did not separately validate the XML signing
  certificate chain or claim an Authenticode verification.
- Innoextract unpacked the archive in a container; no Windows executable,
  driver installer, BIOS updater or EC updater was run.
- Selected `N42QG16W/Core_drivers/qcnspmcdm_ext_cdsp8380/`:
  `qccdsp8380.mbn`, `cdsp_dtbs.elf`, plus `CDSP/fastrpc_shell_3`,
  `fastrpc_shell_unsigned_3`, `libc++.so.1`, `libc++abi.so.1`, `version.so`.
- FastRPC, QAIRT 2.48.0.260626 and Hexagon SDK 6.4.0.2 components are the
  previously staged [HP validation inputs](hp-npu-validation.md). FastRPC's
  per-machine YAML matches the exact device-tree model string
  `Lenovo ThinkPad T14s Gen 6 (LCD)`.

The test used a temporary firmware search directory containing only the
Lenovo cDSP firmware pair at its normal requested relative paths. With no
existing FastRPC clients/listener, it stopped and restarted **cDSP only**
through remoteproc, ran the three tests with temporary listeners, and then
stopped cDSP and restarted the original firmware. aDSP was not restarted.

Kernel logs confirm the test loaded the 3,195,304-byte candidate and cleanup
loaded the original 3,072,424-byte image. After cleanup, both DSPs are running,
the custom firmware search path is empty again, no `cdsprpcd` remains, and
the speaker and camera endpoints are still present. No firmware package,
initramfs, ESP, service enablement or published ISO was changed for the NPU.

The kernel emitted `No context ID matches response` once around each test
process teardown. Tests completed and the machine remained reachable; retain
that observation for FastRPC lifecycle review rather than calling the entire
stack warning-free. Long-running workloads, suspend and reboot regression
remain untested.

The ThinkPad's NPU is therefore functionally validated **with the matched
Lenovo test firmware/runtime**, not ready out of the box on v0.1.0. Permanent
firmware packaging and a supported runtime remain follow-up work. Simply
rerunning the staged harness against the restored stock firmware is not the
validated configuration.

Private local evidence and extraction: `build/t14s-followup/`. Target staging:
`~/npu-test` and `~/t14s-followup`. Test images were not saved or uploaded;
proprietary SDK/driver payloads were not added to the source repository.
