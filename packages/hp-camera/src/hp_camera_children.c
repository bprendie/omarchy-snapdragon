// SPDX-License-Identifier: GPL-2.0-only
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/dmi.h>
static struct platform_device *parent;
static int __init children_init(void)
{
 struct device_node *node;
 int ret;
 if (!dmi_match(DMI_BOARD_NAME, "8CBE")) return -ENODEV;
 node = of_find_node_by_path("/soc@0/isp@acb7000");
 if (!node) return -ENODEV;
 parent = of_find_device_by_node(node);
 if (!parent) { of_node_put(node); return -ENODEV; }
 ret = of_platform_populate(node, NULL, NULL, &parent->dev);
 of_node_put(node);
 if (ret) put_device(&parent->dev);
 return ret;
}
static void __exit children_exit(void)
{
 of_platform_depopulate(&parent->dev);
 put_device(&parent->dev);
}
module_init(children_init);
module_exit(children_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Populate CSI child devices for temporary HP camera overlay");
