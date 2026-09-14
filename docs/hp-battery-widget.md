# HP battery widget follow-up

Read-only investigation on September 13, 2026, HP EliteBook Ultra G1q.
User requested a quick diagnosis and deferral until after kernel work.

**Confirmed userspace device-selection bug:** the installed
`/usr/share/omarchy/bin/omarchy-battery-status` selects the first UPower object
containing uppercase `BAT`. The HP battery object is
`/org/freedesktop/UPower/devices/battery_qcom_battmgr_bat`, so selection is empty
and `omarchy-battery-status --shell` exits successfully with no output.
The power popup gets its text fields from that command; missing percentage
there is consistent with this failure. Its graphical battery level uses
Quickshell's UPower display device separately.

UPower reports a present, charging battery at **99.0002%**, 50.896 Wh of
51.410 Wh, approximately 17.7 W charging. Its aggregate DisplayDevice also
reports the percentage correctly. The kernel exposes energy values but no
`capacity` sysfs file; UPower successfully calculates percentage. This is not
evidence of missing battery telemetry in the kernel.

The bar also has a separate percentage-display toggle (right-click), default
off. That setting does not explain the empty popup command output.

Follow-up: replace the `BAT` name assumption with selection by actual UPower
battery properties, or use the aggregate display battery where appropriate.
Test Qualcomm names, conventional BAT0, no battery, and peripheral batteries
before carrying the fix in the Omarchy source patch and next ISO. Do not edit
the installed package as the durable implementation.

No HP configuration, packages or services were changed during this check.

Rechecked over SSH on September 13 after the user requested the missing
answer: UPower's DisplayDevice reports **100%, fully charged**, with 56.83 Wh
reported for both energy and energy-full. The Qualcomm battery object name
is unchanged and `omarchy-battery-status --shell` still produces no output.
The userspace selection bug remains reproducible; remediation stays deferred
while the kernel update pipeline takes priority.
