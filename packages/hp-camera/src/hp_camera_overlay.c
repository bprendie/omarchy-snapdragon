// SPDX-License-Identifier: GPL-2.0-only
#include <linux/module.h>
#include <linux/of.h>
#include <linux/dmi.h>
#include "overlay-data.h"
static int overlay_id;
static int __init camera_overlay_init(void)
{
 if (!dmi_match(DMI_BOARD_NAME, "8CBE") ||
     !of_machine_is_compatible("hp,elitebook-ultra-g1q")) return -ENODEV;
 return of_overlay_fdt_apply(overlay_data, sizeof(overlay_data), &overlay_id, NULL);
}
static void __exit camera_overlay_exit(void)
{
 int ret = of_overlay_remove(&overlay_id);
 if (ret) pr_err("hp-camera: overlay removal failed: %d\n", ret);
}
module_init(camera_overlay_init);
module_exit(camera_overlay_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Temporary HP camera DT overlay; reboot discards changes");
