#!/bin/sh

# Define usage function
usage() {
	echo "hw2.sh -i INPUT -o OUTPUT [-c csv|tsv] [-j]" >&2
	echo "Available Options:" >&2
	echo "-i: Input file to be decoded" >&2
	echo "-o: Output directory" >&2
	echo "-c csv|tsv: Output files.[ct]sv" >&2
	echo "-j: Output info.json" >&2
	exit 1
}

second_to_date() {
	# Input : seconds since 1970-01-01 00:00:00 UTC(obtained by %s)
	# Output : Formatted Date
	if [ $# -ne 1 ]; then
		echo "Function $0 should accept exactly one argument"
		return 1
	fi
	# echo $(date -d "@$1" "+%FT%T%:z")
	prefix=$(date -r "$1" "+%FT%T")
	suffix=$(date -r "$1" +%z | sed -e 's,\([0-9][0-9]\)\([0-9][0-9]\),\1:\2,')
	echo "$prefix""$suffix"
}

validate_input() {
	# Check if required arguments are provided
	if [ -z "$input" ] || [ -z "$output" ]; then
		usage
	fi

	# Check if input file exists
	if [ ! -f "$input" ]; then
		echo "Error: Input file '$input' does not exist." >&2
		exit 1
	fi
}

validate_output() {
	# create directory if not exist
	if [ ! -d "$output" ]; then
		mkdir "${output}"
	fi
}

validate_optional() {
	if [ $csv -eq 1 ] || [ $tsv -eq 1 ] || [ $json -eq 1 ]; then
		if [ $csv -eq 1 ]; then
			touch "${output}/files.csv"
			echo "filename,size,md5,sha1" >"${output}/files.csv"
		fi
		if [ $tsv -eq 1 ]; then
			touch "${output}/files.tsv"
			printf "filename\tsize\tmd5\tsha1\n" >"${output}/files.tsv"
		fi
		if [ $json -eq 1 ]; then
			touch "${output}/info.json"
		fi
	fi
}

export_to_file() {
	# $1: File Name
	# $2: File Content
	# echo "export to file"
	directory=$(dirname "$1")
	if [ "$directory" != "." ]; then
		mkdir -p "$output/$(dirname "$1")"
	fi
	touch "${output}/$1"
	echo "$2" >"$output/$1"
}

export_to_hw2() {
	# $1: Exported hw2 file name in "output/$filename"
	# echo "export to hw2"
	name=$(yq eval '.name' "$output/$1")
	author=$(yq eval '.author' "$output/$1")
	date=$(yq eval '.date' "$output/$1")
	export_to_json "$name" "$author" "$(second_to_date "$date")"

	num_of_files=$(yq eval '.files | length' "$output/$1")

	for i in $(seq 0 $((num_of_files - 1))); do
		file_name=$(yq eval ".files[${i}].name" "$output/$1")
		file_type=$(yq eval ".files[${i}].type" "$output/$1")
		file_data=$(yq eval ".files[${i}].data" "$output/$1")
		file_val=$(echo "$file_data" | base64 --decode | sha1)
		file_sha1=$(yq eval ".files[${i}].hash.sha-1" "$output/$1")
		if [ "$file_val" != "$file_sha1" ]; then
			invalid=$((invalid+1))
		fi
		file_data=$(echo "${file_data}" | base64 --decode)
		file_md5=$(yq eval ".files[${i}].hash.md5" "$output/$1")
		file_size=${#file_data}

		export_to_tcsv "$file_name" "$((file_size+1))" "$file_md5" "$file_sha1"
		export_to_file "$file_name" "$file_data"
		if [ "$file_type" = "hw2" ]; then
			export_to_hw2 "$file_data"
		fi
	done

	return 0
}

export_to_tcsv() {
	# $1: filename
	# $2: size
	# $3: md5
	# $4: sha-1
	if [ $csv -eq 0 ] && [ $tsv -eq 0 ]; then
		return 0
	fi
	if [ -f "$output/files.csv" ]; then
		echo "$1,$2,$3,$4" >>"$output/files.csv"
	else
		printf "%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4" >>"$output/files.tsv"
	fi
	return 0
}

export_to_json() {
	# $1: filename
	# $2: author
	# $3: date with right format
	if [ $json -eq 0 ]; then
		return 0
	fi
	if [ ! -f "$output/info.json" ]; then
		echo "Error: info.json does not exist."
		return 1
	fi
	{
		echo "{"
		echo "	\"name\": \"$1\","
		echo "	\"author\": \"$2\","
		echo "	\"date\": \"$3\""
		echo "}"
	} >>"${output}/info.json"
	return 0
}

# Initialize variables with default values
# 0 for false, 1 for true
# don't use true/false because if-statement is buggy, I don't know how to fix it.
csv=0
tsv=0
json=0
input=""
output=""
invalid=0

# Initialize variables for file metadata
name=""
author=""
date=""
# data=""

while getopts ":i:o:c:j" opt; do
	case $opt in
	i)
		input="$OPTARG"
		;;
	o)
		output="$OPTARG"
		;;
	c)
		case $OPTARG in
		csv)
			csv=1
			;;
		tsv)
			tsv=1
			;;
		*)
			usage
			;;
		esac
		;;
	j)
		json=1
		;;
	*)
		usage
		;;
	esac
done

validate_input
validate_output
validate_optional

# No Recursive
# Parse YAML file with yq
name=$(yq eval '.name' "$input")
author=$(yq eval '.author' "$input")
date=$(yq eval '.date' "$input")
export_to_json "$name" "$author" "$(second_to_date "$date")"

num_of_files=$(yq eval '.files | length' "$input")

for i in $(seq 0 $((num_of_files - 1))); do
	file_name=$(yq eval ".files[${i}].name" "$input")
	file_type=$(yq eval ".files[${i}].type" "$input")
	file_data=$(yq eval ".files[${i}].data" "$input")
	file_val=$(echo "$file_data" | base64 --decode | sha1)
	file_sha1=$(yq eval ".files[${i}].hash.sha-1" "$input")
	if [ "$file_val" != "$file_sha1" ]; then
		invalid=$((invalid+1))
	fi
	file_data=$(echo "${file_data}" | base64 --decode)
	file_md5=$(yq eval ".files[${i}].hash.md5" "$input")
	file_size=${#file_data}

	export_to_tcsv "$file_name" "$((file_size+1))" "$file_md5" "$file_sha1"
	export_to_file "$file_name" "$file_data"
	if [ "$file_type" = "hw2" ]; then
		export_to_hw2 "$file_name"
	fi
done
return "$invalid"
