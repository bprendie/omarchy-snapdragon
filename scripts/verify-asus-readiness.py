#!/usr/bin/env python3
"""Static UX3407RA checks; does not establish physical camera/display operation.

Usage: verify-asus-readiness.py KERNEL.EFI ROOT INITRAMFS-CONTENTS.txt
Requires fdtget (dtc). Pass fresh lsinitcpio output for the image being checked.
"""
import pathlib
import struct
import subprocess
import sys
import tempfile


def require(ok, message):
    if not ok:
        raise SystemExit("FAIL: " + message)


require(len(sys.argv) == 4, __doc__)
kernel, root, listing = map(pathlib.Path, sys.argv[1:])
data = kernel.read_bytes()
require(data[:2] == b"MZ", "EFI executable header")
pe = struct.unpack_from("<I", data, 0x3C)[0]
require(data[pe:pe + 4] == b"PE\0\0", "PE signature")
machine, count = struct.unpack_from("<HH", data, pe + 4)
require(machine == 0xAA64, "ARM64 kernel")
optional = struct.unpack_from("<H", data, pe + 20)[0]
trees = []
with tempfile.TemporaryDirectory(prefix="asus-readiness-") as tmp:
    dtb = pathlib.Path(tmp) / "board.dtb"

    def prop(node, name, default=None):
        args = ["fdtget"]
        if default is not None:
            args += ["-d", default]
        return subprocess.check_output(
            args + [str(dtb), node, name], text=True).strip()

    for i in range(count):
        offset = pe + 24 + optional + i * 40
        if data[offset:offset + 8].rstrip(b"\0") != b".dtbauto":
            continue
        size, start = struct.unpack_from("<II", data, offset + 16)
        dtb.write_bytes(data[start:start + size])
        if "asus,zenbook-a14-ux3407ra" in prop("/", "compatible").split():
            trees.append(dtb.read_bytes())
    require(len(trees) == 1, "exactly one embedded UX3407RA tree")
    dtb.write_bytes(trees[0])
    cci = "/soc@0/cci@ac16000"
    camera = cci + "/i2c-bus@1/camera@36"
    camss = "/soc@0/isp@acb7000"
    for node in [cci, cci + "/i2c-bus@1", camera, camss,
                 camss + "/phy@acec000"]:
        require(prop(node, "status", "okay") in ("okay", "ok"), node + " enabled")
    require(prop(camera, "compatible") == "ovti,ov02c10", "OV02C10 sensor")
    sensor_ep = camera + "/port/endpoint"
    receiver_ep = camss + "/ports/port@3/endpoint@4"
    require(prop(sensor_ep, "remote-endpoint") == prop(receiver_ep, "phandle")
            and prop(receiver_ep, "remote-endpoint") == prop(sensor_ep, "phandle"),
            "reciprocal sensor/CSI4 graph")
    print("PASS: embedded ASUS RGB camera graph enabled and connected")

modules = root / "usr/lib/modules/7.0.0-31-generic"
for name in ["ov02c10", "qcom-camss", "phy-qcom-mipi-csi2", "i2c-qcom-cci"]:
    require(any(modules.rglob(name + ".ko*")), "root camera driver: " + name)
db = root / "var/lib/pacman/local"
for package in ["libcamera", "libcamera-ipa", "libcamera-tools", "pipewire-libcamera",
                "gst-plugin-libcamera"]:
    require(any(db.glob(package + "-[0-9]*")), "installed camera package: " + package)
print("PASS: camera drivers and userspace packages present")

contents = listing.read_text().splitlines()
names = {pathlib.PurePosixPath(p).name.split(".ko")[0].replace("-", "_")
         for p in contents if ".ko" in p}
for module in ["msm", "panel_samsung_atna33xc20", "drm_dp_aux_bus", "ps883x",
               "pmic_glink", "pmic_glink_altmode", "qcom_q6v5_pas", "qrtr_smd",
               "pinctrl_spmi_gpio", "pinctrl_x1e80100", "fixed", "phy_qcom_edp",
               "nvmem_qfprom", "qcom_hwspinlock", "i2c_hid_of"]:
    require(module in names, "early display/input prerequisite: " + module)
firmware = pathlib.Path(__file__).resolve().parents[1] / "profiles/asus-zenbook-a14-ux3407ra/firmware.required"
for name in firmware.read_text().splitlines():
    path = "usr/lib/firmware/7.0.0-31-generic/" + name
    require((root / path).is_file() and path in contents, "root/early firmware: " + name)
print("PASS: selected ASUS early display/input modules and all five firmware files")
print("Hardware remains UNTESTED; this checks known prerequisites, not probe timing or pixels.")
