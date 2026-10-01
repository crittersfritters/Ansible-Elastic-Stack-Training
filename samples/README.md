# Sample data

The mission samples exercise both configured parser formats, a total nonmatch,
and a structurally matched record whose date cannot be converted. Send one
record at a time to TCP/4444 and compare the indexed result with
`mission/expected-outcomes.yml`.

The Zeek and Suricata fixtures are small examples for format inspection and
controlled testing. They do not replace installing the sensors or demonstrating
that those sensors can generate fresh logs on the training host.
