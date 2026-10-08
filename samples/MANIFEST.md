# Sample manifest

These sanitized fixtures are test inputs, not completed parser or service
configuration. `mission/expected-outcomes.yml` defines observable behavior and
types without supplying a Grok expression.

| File | Purpose |
|---|---|
| `zeek/conn.log` | Inspect and trace one Zeek JSON connection event |
| `suricata/eve.json` | Inspect and trace one Suricata EVE JSON alert |
| `mission/pan-simple.log` | Develop the smaller ordered mission parser |
| `mission/pan-full.log` | Develop the larger ordered mission parser |
| `mission/unmatched.log` | Exercise total nonmatch handling |
| `mission/date-failure.log` | Exercise a structural match with an invalid calendar date |
| `mission/expected-outcomes.yml` | Required destinations, parser identities, timestamps, fields, and types |

The sensor fixtures do not replace installing Zeek and Suricata or proving
that each can produce a fresh record. If you inject a fixture into a live
source path, preserve the original and record exactly what you changed.

## SHA-256

```text
ec1670e581daefc525de23a3d7fa4ffb31000a4d7f2023767fafe8317e3477c1  mission/date-failure.log
aa8fd45385ea80933e04b02669ec1f0cea7a05882af310315269fcfc510e843d  mission/pan-full.log
a6f079bf5befde04387e43e2c842ce2d6a3ee4d57365ebaf0d5bcd3ddc3760da  mission/pan-simple.log
b57072ce8e67e1b41434b58b6611e095cd91d5e28d7d48608b41edb8c006fbb5  mission/unmatched.log
02f60fcb4308060fe0984227cb36651c71e2781ae95bb8950d7505766f49ba9e  mission/expected-outcomes.yml
97776a2c99bf2fa0f987ba3657b5bc8f674d41559e13e59b187f2c389aa3b4dc  zeek/conn.log
76e59e0beab804ad8f9bf7105abad08af8255a0808496f1d1506c40c348afac9  suricata/eve.json
```
