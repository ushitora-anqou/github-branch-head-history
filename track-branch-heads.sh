#!/usr/bin/env bash
set -euo pipefail

REPOSITORIES_FILE="repositories"

if [[ ! -f "$REPOSITORIES_FILE" ]]; then
	echo "::warning::repositories file not found"
	exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

while IFS= read -r line || [[ -n "$line" ]]; do
	# Skip empty lines and comments
	[[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

	# Parse: URL and branch are whitespace-separated
	read -r repo_url branch <<<"$line"

	if [[ -z "$repo_url" || -z "$branch" ]]; then
		echo "::warning::Skipping malformed line: $line"
		continue
	fi

	# Sanitize URL: replace :, /, . with _
	sanitized_url=$(echo "$repo_url" | sed 's/[:/.]/_/g')

	history_dir="history/${sanitized_url}/${branch}"
	history_file="${history_dir}/history.txt"

	# Shallow bare clone of the single branch
	clone_dir="${TMPDIR}/${sanitized_url}_${branch}"
	if ! git clone --depth=1 --bare --single-branch --branch "$branch" "$repo_url" "$clone_dir" 2>/dev/null; then
		echo "::warning::Failed to clone ${repo_url} branch ${branch}"
		continue
	fi

	# Get commit hash, author date, committer date
	log_output=$(git -C "$clone_dir" log -1 --format='%H %aI %cI')
	if [[ -z "$log_output" ]]; then
		echo "::warning::No commits on ${repo_url} branch ${branch}"
		continue
	fi

	commit_hash=$(echo "$log_output" | awk '{print $1}')
	author_date=$(echo "$log_output" | awk '{print $2}')
	committer_date=$(echo "$log_output" | awk '{print $3}')

	# Current UTC datetime in RFC3339
	clone_datetime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	mkdir -p "$history_dir"

	new_line="${clone_datetime} ${commit_hash} ${author_date} ${committer_date}"

	should_append=true
	if [[ -f "$history_file" ]]; then
		last_hash=$(tail -1 "$history_file" | awk '{print $2}')
		if [[ "$last_hash" == "$commit_hash" ]]; then
			should_append=false
			echo "No change for ${repo_url} ${branch} (${commit_hash})"
		fi
	fi

	if $should_append; then
		echo "$new_line" >>"$history_file"
		echo "Recorded new head for ${repo_url} ${branch}: ${commit_hash}"
	fi

done <"$REPOSITORIES_FILE"
