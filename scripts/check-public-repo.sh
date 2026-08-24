#!/usr/bin/env bash
set -euo pipefail

blocked_paths='(^|/)(\.env($|\.)|\.dev\.vars|\.wrangler($|/)|google-services\.json|GoogleService-Info\.plist|firebase-adminsdk-.*\.json|service-account.*\.json|.*\.(pem|p12|key|keystore|jks))$'
credential_pattern='(AIza[0-9A-Za-z_-]{20,}|(api[_-]?key|secret|password|token)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,})'

failed=0

tracked_files=()
while IFS= read -r file; do
  [[ -f "$file" ]] && tracked_files+=("$file")
done < <(git ls-files -co --exclude-standard)

if blocked=$(printf '%s\n' "${tracked_files[@]}" | grep -E "$blocked_paths" || true); [[ -n "$blocked" ]]; then
  echo 'Blocked sensitive file(s) are tracked:' >&2
  echo "$blocked" >&2
  failed=1
fi

scan_files=()
for file in "${tracked_files[@]}"; do
  case "$file" in
    scripts/check-public-repo.sh) ;;
    *) scan_files+=("$file") ;;
  esac
done

if matches=$( {
  grep -n -I -F -- 'PRIVATE KEY' "${scan_files[@]}" || true
  grep -n -I -E -- "$credential_pattern" "${scan_files[@]}" || true
} ); [[ -n "$matches" ]]; then
  echo 'Possible credential(s) found in tracked text:' >&2
  echo "$matches" >&2
  failed=1
fi

if (( failed )); then
  echo 'Remove the sensitive content and rotate any exposed credential before publishing.' >&2
  exit 1
fi

echo 'Public-repository safety check passed.'
