#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 테두리 그리기 함수
draw_border() {
    local width=$(tput cols)
    for ((i=0; i<width; i++)); do
        echo -n "-"
    done
    echo
}

# 로고 및 타이틀 출력 함수
print_logo() {
    clear
    draw_border
    echo -e "${BLUE}${BOLD}"
    echo "		╭━━╮╱╱╱╱╱╭╮╱╱╱╭╮╭╮╱╭━━━┳╮╭━┳━━━┳━━━╮"
    echo "		╰┫┣╯╱╱╱╱╭╯╰╮╱╱┃┃┃┃╱┃╭━╮┃┃┃╭┫╭━━┫╭━╮┃"
    echo "		╱┃┃╭━╮╭━┻╮╭╋━━┫┃┃┃╱┃╰━╯┃╰╯╯┃╰━━╋╯╭╯┃"
    echo "		╱┃┃┃╭╮┫━━┫┃┃╭╮┃┃┃┃╱┃╭╮╭┫╭╮┃┃╭━━╋━╯╭╯"
    echo "		╭┫┣┫┃┃┣━━┃╰┫╭╮┃╰┫╰╮┃┃┃╰┫┃┃╰┫╰━━┫┃╰━╮"
    echo "		╰━━┻╯╰┻━━┻━┻╯╰┻━┻━╯╰╯╰━┻╯╰━┻━━━┻━━━╯"
    echo -e "${NC}"
    draw_border
    echo -e "${CYAN}${BOLD}(Install RKE2)${NC}"
    echo
}



# 메인 메뉴 출력 함수
print_main_menu() {
    print_logo
    echo -e "${GREEN}실행할 작업을 선택하세요:${NC}"
    echo
}

# Playbook 파일 경로 정의
INSTALL_PLAYBOOK="playbook.yaml"
UNINSTALL_PLAYBOOK="uninstall-playbook.yaml"

run_playbook() {
    local playbook_file=$1
    shift
    echo -e "${GREEN}Ansible Playbook을 실행합니다...${NC}"
    echo -e "${YELLOW}실행할 파일: $playbook_file${NC}"
    ansible-playbook "$playbook_file" "$@"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Playbook 실행이 완료되었습니다.${NC}"
    else
        echo -e "${RED}Playbook 실행 중 오류가 발생했습니다.${NC}"
    fi
}


# 전체 삭제 확인 함수
confirm_uninstall() {
    read -p "정말로 전체 삭제를 진행하시겠습니까? (y/n) " confirm
    case "$confirm" in
        y|Y)
            run_playbook "$UNINSTALL_PLAYBOOK"
            ;;
        *)
            echo -e "${YELLOW}전체 삭제를 취소했습니다.${NC}"
            ;;
    esac
}


select_action() {
    while true; do
        print_main_menu
        options=("전체 설치" "단일 작업 설치" "특정 작업 이후부터 설치" "전체 삭제" "종료")
        arrow_select "${options[@]}"
        choice=$?
        case $choice in
	    0)
                run_playbook "$INSTALL_PLAYBOOK"
                echo -e "${YELLOW}전체 설치가 완료되었습니다. CN studio를 종료합니다.${NC}"
                exit 0
                ;;
            1) select_play "단일" ;;
            2) select_play "이후" ;;
            3) confirm_uninstall ;;
            4) echo -e "${YELLOW}CN studio를 종료합니다.${NC}"; exit 0 ;;
        esac
    done
}

select_play() {
    local mode=$1
    print_logo
    echo -e "${GREEN}설치할 작업을 선택하세요:${NC}"
    echo

    # 번호가 매겨진 옵션 배열 생성
    local numbered_options=()
    for i in "${!PLAY_NAMES[@]}"; do
        numbered_options+=("$((i+1)). ${PLAY_NAMES[$i]}")
    done
    numbered_options+=("돌아가기")  # 번호 없이 "돌아가기" 추가

    arrow_select "${numbered_options[@]}"
    choice=$?
    if [ $choice -eq $((${#numbered_options[@]} - 1)) ]; then
        return
    else
        local selected_play="${PLAY_NAMES[$choice]}"
        if [ "$mode" == "단일" ]; then
	    local selected_tag=$(get_tag_for_play "$selected_play")
   	    echo -e "${CYAN}선택한 작업: $selected_play${NC}"
   	    run_playbook "$INSTALL_PLAYBOOK" --tags "$selected_tag" -v
   	    exit 0
        else
            # 특정 작업 이후 설치
            local start_found=false
            local tags_to_run=($(echo "${tags_to_run[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

            for play in "${PLAY_NAMES[@]}"; do
                if [ "$start_found" = true ] || [ "$play" = "$selected_play" ]; then
                    start_found=true
                    local play_tag=$(get_tag_for_play "$play")
                    tags_to_run+=("$play_tag")
                fi
            done

            if [ ${#tags_to_run[@]} -eq 0 ]; then
                echo -e "${RED}오류: 선택한 작업 이후의 태그를 찾을 수 없습니다.${NC}"
                return
            else
                # 중복 태그 제거
                tags_to_run=( $(echo "${tags_to_run[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ') )

		local tag_list=$(IFS=,; echo "${tags_to_run[*]}")
		echo -e "${GREEN}'$selected_play' 이후의 모든 작업을 설치합니다.${NC}"
		run_playbook "$INSTALL_PLAYBOOK" --tags "$tag_list"
                exit 0
            fi
        fi
    fi
}


arrow_select() {
    local options=("$@")
    local selected=0
    local key

    print_options() {
        local i
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -en "\r\033[K${GREEN}> ${options[$i]}${NC}"
            else
                echo -en "\r\033[K  ${options[$i]}"
            fi
            echo
        done
    }

    print_options

    while true; do
        read -rsn1 key 2>/dev/null >&2
        case "$key" in
            A)
                ((selected--))
                [ $selected -lt 0 ] && selected=$((${#options[@]} - 1))
                ;;
            B)
                ((selected++))
                [ $selected -ge ${#options[@]} ] && selected=0
                ;;
            '')
                echo
                return $selected
                ;;
        esac

        echo -en "\033[${#options[@]}A"
        print_options
    done
}

# Playbook 파일 경로 정의 및 파일 존재 확인
if [ ! -f "$INSTALL_PLAYBOOK" ]; then
    echo -e "${RED}오류: $INSTALL_PLAYBOOK 파일을 찾을 수 없습니다.${NC}"
    exit 1
fi

if [ ! -f "$UNINSTALL_PLAYBOOK" ]; then
    echo -e "${RED}오류: $UNINSTALL_PLAYBOOK 파일을 찾을 수 없습니다.${NC}"
    exit 1
fi

# yq 도구 확인
if ! command -v yq &> /dev/null; then
    echo -e "${RED}오류: yq 도구가 설치되어 있지 않습니다. 설치 후 다시 시도해주세요.${NC}"
    exit 1
fi

# Playbook에서 play 이름 추출
get_play_names() {
    yq e '.[].name' "$INSTALL_PLAYBOOK" | sed 's/^- //'
}

# Playbook에서 태그 추출
get_tags() {
    yq e '.[].tags[]' "$INSTALL_PLAYBOOK" | sort -u
}

# Play 이름으로 태그 가져오기
get_tag_for_play() {
    local play_name="$1"
    yq e ".[] | select(.name == \"$play_name\") | .tags[]" "$INSTALL_PLAYBOOK"
}

# 변수 초기화
readarray -t PLAY_NAMES < <(get_play_names)
TAGS=($(get_tags))

# 메인 스크립트 실행
select_action
