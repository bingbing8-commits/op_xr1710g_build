FNR == NR {
	if ($0 ~ /^CONFIG_PACKAGE_.*=[ym]$/) {
		package = $0
		sub(/^CONFIG_PACKAGE_/, "", package)
		sub(/=[ym]$/, "", package)
		selected[package] = 1
	}
	next
}

/^Source-Makefile:[[:space:]]*/ {
	source = $0
	sub(/^Source-Makefile:[[:space:]]*/, "", source)
	sub(/\/Makefile$/, "", source)
	next
}

/^Package:[[:space:]]*/ {
	package = $0
	sub(/^Package:[[:space:]]*/, "", package)
	sub(/[[:space:]]*$/, "", package)
	if (selected[package] && source != "")
		print source
}
