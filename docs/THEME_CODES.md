# Theme codes

A shared theme is a JSON document validated against
`schemas/theme-code.schema.json`, encoded as UTF-8, and wrapped by
`ThemeCodeCodec`.

The public code format is:

```text
SPT1.<base64url-without-padding>.<crc32-hex>
```

CRC32 detects accidental corruption; it is not a signature or authentication
mechanism. Decoders must enforce the 4 KiB decoded-size limit, schema version,
color syntax, and field-length limits before displaying a preview. Applying a
theme requires explicit user confirmation.

Theme codes contain visual settings only. They must never contain profiles,
test results, analytics state, server URLs, tokens, or passwords.
