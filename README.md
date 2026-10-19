Nifi-test V4
V4 preserves the working v3.2-password flow and centralizes 35 configuration values. No SSH private key is required. The source pickup remains GetSFTP without timestamp tracking.
Procedure for every deployment
1. Put Nifi-test-v4.json, Nifi-test-v4-variables.json and render-nifi-v4.sh in one directory on a Linux machine with Bash and Python 3. This can be Server B.
2. Edit Nifi-test-v4-variables.json. Fill PasswordA and APIKeyC: replace null with quoted JSON strings. Update any host, username, directory, workflow or tuning values you need. All values must be JSON strings. For example, a port is "22", not 22. JSON requires escaping a literal backslash as \\ and a literal double quote as \". Dollar signs and exclamation marks need no escaping in the JSON file. Keep the variables file private, for example chmod 600 Nifi-test-v4-variables.json.
3. Generate the import file:
bash render-nifi-v4.sh Nifi-test-v4.json Nifi-test-v4-variables.json Nifi-test-v4-ready.json
4. Stop the old process group before testing the new group against the same source directory. Import Nifi-test-v4-ready.json manually into NiFi. Review validation and start only the intended group. The script does not connect to any server or import anything.
The template and variables file are never overwritten. Choose a new output filename on later runs, such as Nifi-test-v4-ready-02.json. Output is created with owner-only read/write permissions. It contains plaintext credentials; do not share that generated copy. The supplied template and variables file have blank credentials.
Main settings
Variable	Default / purpose
ServerA / PortA	192.168.2.207 / 22; SFTP server
UsernameA / PasswordA	henry.zhang / fill in; shared by 01, 10, 11 and 12
SourceDirectoryA	/C:/Nifi-Test/MDUpdate1
PassDirectoryA	/C:/Nifi-Test/Pass
FailedDirectoryA	/C:/Nifi-Test/Failed
OthersDirectoryA	/C:/Nifi-Test/Others
ServerC / ProtocolC / PortC	192.168.2.207 / http / 8008
APIPathC / APIKeyC	/file / fill in; shared by 03 and 06
WorkflowC	MDC-Update; must exist and be authorized in MDC
AllowedPrefix / BlockedPrefix / OthersPrefix	Allowed_ / Blocked_ / Others_
PollingMaxRetries	1440; existing 10-second retry penalty retained
SubmissionMaxRetries / DeliveryMaxRetries	5 / 5


The remaining values in the variables file cover SFTP/HTTP timeouts, listing/filter settings, response size and target conflict behavior. Server C uses an API key, so it has no separate UsernameC or PasswordC. Server B's NiFi UI address is not part of processor configuration.
What the script does
The normal command replaces every #{ParameterName} reference in the flow with its corresponding value, removes the now-unused Parameter Context, and writes valid JSON. Runtime NiFi expressions such as ${md.data_id} and ${nifi.original.filename} remain unchanged. Credential characters are serialized as JSON data and are never executed as shell commands. Missing, empty, unknown and duplicate variables are rejected; existing output files are not overwritten. No variable values are printed.
Optional advanced mode: append --context to retain NiFi parameter references and fill the embedded Parameter Context instead. In that mode, after import the values can also be maintained in Parameter Contexts → Nifi-test-v4-Parameters. The normal command above is the requested replace-all workflow.
Sensitive-value handling can differ during NiFi export/import. If NiFi leaves Password or the sensitive apikey header unset after import, enter the values in the affected processor properties (01/10/11/12 for Password; 03/06 for apikey), or use the optional context mode and fill the two sensitive parameters there. Live import has not been verified against your NiFi instance.
Preserved flow behavior
- 01 downloads the original through SFTP and removes it from the source after successful retrieval. The NiFi content copy then goes to MDC and, after routing, back to the selected directory on Server A.
- Allowed files go to Pass, Blocked files to Failed, and inconclusive results or exhausted scan retries to Others. Existing routing rules are unchanged.
- Repeated destination names use REPLACE. Failed delivery handling and the disabled HOLD ERRORS processor remain unchanged.
- File-copy completion detection is unchanged: stop 01 while copying files directly into the source, then start it after copying finishes, or stage completed files elsewhere and move them into the watched directory. This version does not add a size-stability check.
- Processor scheduling, queue limits, routing expressions and topology remain fixed. They are not deployment variables. The graph retains 22 processors and 38 connections.
Static checks and shell rendering tests passed, including special characters in passwords, preserved runtime expressions, private output permissions and missing-value/overwrite protection. A live server test remains necessary after import.
