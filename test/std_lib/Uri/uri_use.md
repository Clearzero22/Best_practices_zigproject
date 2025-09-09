This is a well-structured Zig implementation of a **Uniform Resource Identifier (URI) parser and formatter**, loosely based on [RFC 3986](https://tools.ietf.org/html/rfc3986). It's designed to be robust for real-world URIs, including those found in HTTP headers or user input, even if they're not perfectly compliant.

---

### 🔍 Overview

The code defines a `Uri` struct that represents a parsed URI with the following components:

```zig
scheme: []const u8,
user: ?Component = null,
password: ?Component = null,
host: ?Component = null,
port: ?u16 = null,
path: Component = Component.empty,
query: ?Component = null,
fragment: ?Component = null,
```

Each component (except scheme and port) uses a `union(enum)` type called `Component`, which can store strings either as:
- `.raw`: Unencoded string (needs percent-encoding before output)
- `.percent_encoded`: Already encoded (safe to print directly)

This design allows efficient handling without unnecessary re-encoding.

---

### ✅ Key Features

#### 1. **Parsing (`parse`, `parseAfterScheme`)**
- Parses URIs like `"https://user:pass@host:port/path?query#frag"`
- Supports IPv4, IPv6 (in brackets), domain names, ports, userinfo.
- Tolerates some malformed inputs but returns errors for clearly invalid ones.
- Does **not** validate full grammar strictly — prioritizes usability over strict compliance.

> Example:
> ```zig
> const uri = try Uri.parse("https://alice:secret@[::1]:8080/home?key=val#top");
> ```

#### 2. **Percent Encoding / Decoding**
- `percentDecodeBackwards` / `percentDecodeInPlace`: Safely decode `%XX` sequences.
- `Component.percentEncode`: Encodes raw strings using specific character sets (e.g., `isUserChar`, `isPathChar`).

Useful for safely formatting parts of URIs.

#### 3. **Formatting & Printing**
- Uses `std.fmt` integration via `.fmt()` method.
- Customizable output using `Format.Flags`:
    - Include/exclude scheme, auth, path, query, fragment, etc.
    - E.g., redact password by setting `.authentication = true` only when needed.

Example:
```zig
try uri.format(&writer); // Full URI
try uri.fmt(.{ .scheme = true, .authority = true }).format(&writer); // Just scheme + authority
```

#### 4. **Resolving Relative URIs (`resolveInPlace`)**
Implements RFC 3986 Section 5 logic:
- Resolves relative URIs against a base URI.
- Handles dot-segment removal (`.` and `..` in paths).
- Merges paths correctly when needed.

Efficient because it works **in-place** where possible.

#### 5. **Dot Segment Removal (`remove_dot_segments`)**
Handles normalization of paths like:
- `/a/b/c/./../../g` → `/a/g`
- Done in-place for performance.

#### 6. **Host Accessors**
Two safe ways to get host:
- `getHost(buffer)` – tries to avoid allocation
- `getHostAlloc(allocator)` – allocates only if decoding is required

Both enforce max DNS name length (`255` chars).

---

### 🛠️ Design Highlights

| Feature | Why It Matters |
|-------|----------------|
| **No copies unless necessary** | Strings point into original input buffer; saves memory |
| **Flexible encoding model** | Raw vs percent-encoded union avoids double-encoding bugs |
| **In-place operations** | Good for low-allocation environments |
| **Robust error handling** | Returns descriptive errors like `InvalidPort`, `UriMissingHost` |
| **Extensive test suite** | Covers edge cases from RFCs, Wikipedia, real-world examples |

---

### ⚠️ Limitations / Notes

- ❌ Not fully RFC-compliant: The doc says so explicitly. Meant for practical use, not standards purity.
- 🔤 Character set checking is basic: Uses simple ASCII checks (`isUnreserved`, `isSubDelims`, etc.), no UTF-8 validation beyond what’s implied by percent-decoding.
- 🧩 No parsing of query parameters: Leaves `query` as a single string. You’d need another layer for key-value parsing.
- 🖥️ IPv6 zone indices supported syntactically (e.g., `%25eth0`), but not validated semantically.
- 📦 Requires caller to manage buffers/memory (especially in `resolveInPlace`).

---

### 💡 Usage Examples

#### Parse and Print
```zig
const uri = try Uri.parse("https://example.com:8080/path?x=1#section");
var buf: [256]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buf);
try uri.writeToStream(&fba.writer(), .{
    .scheme = true,
    .authority = true,
    .path = true,
});
```

#### Get Host Safely
```zig
var host_buf: [Uri.host_name_max]u8 = undefined;
const host = try uri.getHost(&host_buf);
std.debug.print("Host: {s}\n", .{host});
```

#### Resolve a Relative URI
```zig
const base = try Uri.parse("http://a/b/c/d;p?q");
var aux_buffer = "g" ** 256; // Simulated auxiliary buffer
var aux_slice: []u8 = &aux_buffer;

const resolved = try Uri.resolveInPlace(base, 1, &aux_slice);
// Result: http://a/b/c/g
```

---

### ✅ Tests Included

The file includes comprehensive tests:
- Basic parsing
- Authority (user, pass, host, port)
- IPv6 literals
- Path merging and dot-segment removal
- Percent encoding/decoding
- Real-world examples (YouTube, GitHub, LDAP, mailto, etc.)
- Malformed input rejection

All pass, indicating solid correctness within its intended scope.

---

### 🏁 Conclusion

This is a **pragmatic, efficient, and production-ready URI utility** for Zig systems programming:
- Ideal for web servers, clients, proxies, config parsers.
- Balances correctness with flexibility.
- Memory-safe and allocation-aware.
- Well-tested and documented.

It reflects Zig’s philosophy: explicit control, zero-cost abstractions, and clarity over magic.

If you're building anything that handles URLs in Zig — this is an excellent foundation.