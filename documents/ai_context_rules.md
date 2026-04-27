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

**Rule going forward:**
NEVER use Buffer, require(), process, or any other Node.js globals inside n8n 
expression fields (={{ }}). These are only valid inside Code nodes. If base64 
encoding, JSON stringification, or any Node.js operation is needed to prepare 
an HTTP request body, it must be done in a preceding Code node first, with the 
result stored as a plain field in $json for the HTTP node to reference.

**Rules going forward:**
1. NEVER use Switch nodes for binary (two-output) routing decisions. 
   Always use an If node. Switch nodes are for 3+ output routing only.
2. NEVER reference $json.execution.error.node.name in Error Alert expressions. 
   Code node errors do not populate a node sub-object. Always use 
   $json.execution.lastNodeExecuted for the failing node name.

**Rule going forward:**
- n8n If node typeVersion 2 conditions ALWAYS require: 
  (a) `"combinator": "and"` at the conditions root level
  (b) a unique `"id"` string on every condition object  
  (c) a `"name"` field on every operator object
  (d) `"typeValidation": "loose"` when comparing expression values to 
      string literals
- GUARD clauses in Code nodes must use `return []` not `throw` when the 
  intent is to silently stop a leaked item. Only use `throw` when you 
  genuinely want the Error Trigger to fire.