# AI CONTEXT RULES

## Rule: Improve CI/CD commit messages

**Context:** Any update through the CI/CD workflow with a commit message

**Rule:**
For commit messages prefix the commit message with the version number. Make the type of change all upper case. Use sentence case for the portion of the message following the colon.

**Example:**

_wrong:_

```fix(evolution): resolve mutex collision on manual triggers and enforce explicit IGNORE routing for test payloads```

_correct:_
```43.1.9 - FIX(evolution): Resolve mutex collision on manual triggers and enforce explicit IGNORE routing for test payloads```

**Why:**
This will make commits more human readable and will enable easier tracing through the CI/CD.

## Rule: n8n HTTP Request URL Fields — No String Concatenation

**Context:** n8n HTTP Request node (any typeVersion)

-------------------------------------------------------------------------------------

**Rule:**
The `url` parameter in an n8n HTTP Request node must **always** be a complete, literal URL string. Never split `https://` from the rest of the URL using string concatenation (e.g., `"https://" + "domain.com/path"`), even when using the `=` expression prefix.

**Why:** n8n validates the `url` field statically before evaluating expressions. A concatenated string like `"https://" + "chat.googleapis.com/..."` is not a valid URL at parse time and will throw a `NodeOperationError` at runtime.

**Allowed — static URL:**
```json
"url": "https://chat.googleapis.com/v1/spaces/SPACE_ID/messages?key=KEY&token=TOKEN"
```

**Allowed — fully dynamic URL using $json data:**
```json
"url": "={{ \"https://firestore.googleapis.com/v1/projects/\" + $json.projectId + \"/databases/...\" }}"
```

**Never allowed:**
```json
"url": "=\"https://\" + \"chat.googleapis.com/v1/spaces/...\""
```

**Corollary:** Only use the `=` expression prefix on a `url` field when at least one segment of the URL is genuinely dynamic (i.e., references `$json`, `$env`, or another n8n variable). If the entire URL is static, it must be a plain string with no `=` prefix and no concatenation.




**Rule going forward:**
For n8n GitHub node typeVersion 1:
- The `get` operation uses the `reference` parameter (directly in parameters) to specify branch.
- The `edit` operation uses `options.branch` to specify branch.
- NEVER leave either field unset when the target branch is not the repo default. 
  A missing branch is a silent bug — n8n will not warn you, it will just default to 
  main and 404 on any file that only exists on develop.
