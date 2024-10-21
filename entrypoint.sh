#! /usr/bin/env bash
# shellcheck disable=SC2155

input_paths="$1"
severity_mode="$2"
exclude_paths="$3"
execution_mode="$4"
my_dir=$(pwd)
status_code="0"
find_path_clauses=(! -path "${my_dir}/.git/*")
invalid_files=()
scan_regex="#!.*[/= ](sh|bash|dash|ksh)$"

process_input(){      
    [ -n "$execution_mode" ] && my_dir="./test_data"

    severity_mode="$(echo $severity_mode | tr '[:upper:]' '[:lower:]')"

    if [[ "$severity_mode" != "style" && "$severity_mode" != "info" && "$severity_mode" != "warning" && "$severity_mode" != "error" ]]; then
        echo "Warning: unknown severity mode. Defaulting severity mode to style."
        severity_mode="style"
    fi

    if [ -n "$exclude_paths" ]; then
        for path in $(echo "$exclude_paths" | tr "," "\n"); do
            if [ -d "${my_dir}/$path" ]; then
                find_path_clauses+=( ! -path "${my_dir}/$path/*")
            else
                find_path_clauses+=( ! -path "${my_dir}/$path" )
            fi
        done
    fi

    if [[ -n "$input_paths" && "$input_paths" != "." ]]; then
        for path in $(echo "$input_paths" | tr "," "\n"); do
            if [ -d "$path" ]; then
                scan_dir "$path"
            else
                scan_file "$path"
            fi
        done
        [[ ${#invalid_files[@]} -gt 0 ]] && log_invalid_files 
        [ -z "$execution_mode" ] && exit $status_code
    else 
        scan_dir "$my_dir"
        [[ ${#invalid_files[@]} -gt 0 ]] && log_invalid_files
        [ -z "$execution_mode" ] && exit $status_code
    fi
}

scan_file(){
    local file_path=$1
    local file=$(basename -- "$file_path")
    local first_line=$(head -n 1 "$file_path")
    
    if [[ "$first_line" =~ $scan_regex ]]; then
        echo
        echo "###############################################"
        echo "         Scanning $file"
        echo "###############################################"
        shellcheck -x "$file_path" --severity="$severity_mode"
        local exit_code=$?
        if [ $exit_code -eq 0 ] ; then
            printf "%b" "Successfully scanned ${file_path} 🙌\n"
        else
            status_code=$exit_code
            printf "\e[31m ERROR: ShellCheck detected issues in %s.\e[0m\n" "${file_path} 🐛"
        fi
    else
        invalid_files+=( $file_path )
    fi
}

scan_dir(){
    echo "Scanning all the shell scripts at $1 🔎"
    while IFS= read -r script 
    do
        local first_line=$(head -n 2 "$script")
        if [[ "$first_line" =~ $scan_regex ]]; then
            scan_file "$script"
        else
            invalid_files+=( $script )
        fi
    done < <(find "$1" -type f \( -iname '*.sh' -o -iname '*.bash' -o -iname '*.ksh' -o ! -iname '*.*' \) "${find_path_clauses[@]}")
}

# Logging files with no extension that are not amongst the supported scripts or scripts that are supported but don't have a shebang.
log_invalid_files(){
    printf "\n\e[33m ⚠️  Found %d unscanned files that could potentially be supported: \e[0m\n" "${#invalid_files[@]}"
    for file in ${invalid_files[@]}; do
        printf "\n\t\e[33m %s \e[0m\n" "$file"
    done
    printf "\n\e[33m ShellCheck only supports sh/bash/dash/ksh scripts. Ensure a proper shebang on the first line of the script or add the correct flavor of '# shellcheck shell=sh' directly below the shebang.\n\n To fix the warning for the unsupported scripts or to ignore specific files, use the 'exclude-paths' input. For more information check:
    https://github.com/azohra/shell-linter#input\e[0m\n"
}

# To avoid execution when sourcing this script for testing
[ "$0" = "${BASH_SOURCE[0]}" ] && process_input 
