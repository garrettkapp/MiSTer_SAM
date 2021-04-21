#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/media/fat/linux:/media/fat/Scripts:/media/fat/MiSTer_SAM:.

# ======== DEFAULT VARIABLES ========
# Change these in the INI file
mrsampath="/media/fat/MiSTer_SAM"
misterpath="/media/fat/"
corelist="Arcade,GBA,Genesis,MegaCD,NeoGeo,NES,SNES,TGFX16,TGFX16CD"
timer=120

# Path to tools. Change if you have another copy installed and want to share.
mbcpath="${mrsampath}/mbc"
partunpath="${mrsampath}/partun"

# ======== ARCADE OPTIONS ========
mralist=/tmp/.Attract_Mode
mrapath=/media/fat/_Arcade
mrapathvert="${misterpath}/_Arcade/_Organized/_6 Rotation/_Vertical CW 90 Deg"
mrapathhoriz="${misterpath}/_Arcade/_Organized/_6 Rotation/_Horizontal"
orientation=All

# ======== CONSOLE OPTIONS ========
ignorezip="No"
disablebootrom="Yes"
attractquit="Yes"

# ======== INTERNAL VARIABLES ========
declare -i coreretries=3
declare -i romloadfails=0

# ======== CORE CONFIG DATA ========
init_data()
{
	# Core to long name mappings
	declare -gA CORE_PRETTY=( \
		["arcade"]="MiSTer Arcade" \
		["gba"]="Nintendo Game Boy Advance" \
		["genesis"]="Sega Genesis / Megadrive" \
		["megacd"]="Sega CD / Mega CD" \
		["neogeo"]="SNK NeoGeo" \
		["nes"]="Nintendo Entertainment System" \
		["snes"]="Super Nintendo Entertainment System" \
		["tgfx16"]="NEC TurboGrafx-16 / PC Engine" \
		["tgfx16cd"]="NEC TurboGrafx-16 CD / PC Engine CD" \
		)
	
	# Core to file extension mappings
	declare -gA CORE_EXT=( \
		["arcade"]="mra" \
		["gba"]="gba" \
		["genesis"]="md" \
		["megacd"]="chd" \
		["neogeo"]="neo" \
		["nes"]="nes" \
		["snes"]="sfc" \
		["tgfx16"]="pce" \
		["tgfx16cd"]="chd" \
		)
	
	# Core to path mappings
	declare -gA CORE_PATH=( \
		["arcade"]="${mrapath}" \
		["gba"]="${misterpath}/games/GBA" \
		["genesis"]="${misterpath}/games/Genesis" \
		["megacd"]="${misterpath}/games/MegaCD" \
		["neogeo"]="${misterpath}/games/NeoGeo" \
		["nes"]="${misterpath}/games/NES" \
		["snes"]="${misterpath}/games/SNES" \
		["tgfx16"]="${misterpath}/games/TGFX16" \
		["tgfx16cd"]="${misterpath}/games/TGFX16-CD" \
		)
	
	# Can this core use ZIPped ROMs
	declare -gA CORE_ZIPPED=( \
		["arcade"]="No" \
		["gba"]="Yes" \
		["genesis"]="Yes" \
		["megacd"]="No" \
		["neogeo"]="Yes" \
		["nes"]="Yes" \
		["snes"]="Yes" \
		["tgfx16"]="Yes" \
		["tgfx16cd"]="No" \
		)
}


# ======== BASIC FUNCTIONS ========
parse_ini()
{
	basepath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
	if [ -f ${basepath}/Attract_Mode.ini ]; then
		. ${basepath}/Attract_Mode.ini
		IFS=$'\n'
	fi

	# Remove trailing slash from paths
	for var in mrsampath mrapath mrapathvert mrapathhoriz; do
		declare -g ${var}="${!var%/}"
	done

	# Set mrapath based on orientation
	if [ "${orientation,,}" == "vertical" ]; then
		mrapath="${mrapathvert}"
	elif [ "${orientation,,}" == "horizontal" ]; then
		mrapath="${mrapathhoriz}"
	fi
	
	# Setup corelist
	corelist="$(echo ${corelist} | tr ',' ' ')"
}

there_can_be_only_one() # there_can_be_only_one PID Process
{
	# If another attract process is running kill it
	# This can happen if the script is started multiple times
	if [ ! -z "$(pidof -o ${1} $(basename ${2}))" ]; then
		echo ""
		echo "Removing other running instances of $(basename ${2})..."
		kill -9 $(pidof -o ${1} $(basename ${2})) &>/dev/null
	fi
}

parse_cmdline()
{
	for arg in "${@}"; do
		case ${arg,,} in
			arcade)
				echo "${CORE_PRETTY[${arg,,}]} selected!"
				declare -g corelist="Arcade"
				;;
			gba)
				echo "${CORE_PRETTY[${arg,,}]} selected!"
				declare -g corelist="GBA"
				;;
			genesis)
				echo "${CORE_PRETTY[${arg,,}]} selected!"
				declare -g corelist="Genesis"
				;;
			megacd)
				echo "${CORE_PRETTY[${arg,,}]} selected!"
				declare -g corelist="MegaCD"
				;;
			neogeo)
				echo "${CORE_PRETTY[${arg,,}]} selected!"
				declare -g corelist="NeoGeo"
				;;
			nes)
				echo "${CORE_PRETTY[${arg,,}]} selected!"
				declare -g corelist="NES"
				;;
			snes)
				echo "${CORE_PRETTY[${arg,,}]} selected!"
				declare -g corelist="SNES"
				;;
			tgfx16cd)
				echo "${CORE_PRETTY[${arg,,}]} selected!"
				declare -g corelist="TGFX16CD"
				;;
			tgfx16)
				echo "${CORE_PRETTY[${arg,,}]} selected!"
				declare -g corelist="TGFX16"
				;;
			next) # Load one random core and exit
				gonext="next_core"
				;;
		esac
	done

	# If we need to go somewhere special - do it here
	if [ ! -z "${gonext}" ]; then
		${gonext}
		exit 0
	fi
}


# ======== MISTER CORE FUNCTIONS ========
loop_core()
{
	while :; do
		counter=${timer}
		next_core
		while [ ${counter} -gt 0 ]; do
			sleep 1
			((counter--))
			if [ -s /tmp/.SAM_Joy_Activity ]; then
				echo "Controller activity detected!"
				exit
			fi
			if [ -s /tmp/.SAM_Keyboard_Activity ]; then
				echo "Keyboard activity detected!"
				exit
			fi
			if [ -s /tmp/.SAM_Mouse_Activity ]; then
				echo "Mouse activity detected!"
				exit
			fi
		done
	done
}

next_core() # next_core (nextcore)
{
	if [ -z "${corelist[@]//[[:blank:]]/}" ]; then
		echo "ERROR: FATAL - List of cores is empty. Nothing to do!"
		exit 1
	fi

	if [ -z "${1}" ]; then
		nextcore="$(echo ${corelist}| xargs shuf -n1 -e)"
	else
		nextcore="${1}"
	fi

	if [ "${nextcore,,}" == "arcade" ]; then
		load_core_arcade
		return
	elif [ "${CORE_ZIPPED[${nextcore,,}],,}" == "yes" ]; then
		# If not ZIP in game directory OR if ignoring ZIP
		if [ -z "$(find ${CORE_PATH[${nextcore,,}]} -maxdepth 1 -type f \( -iname "*.zip" \))" ] || [ "${ignorezip,,}" == "yes" ]; then
			rompath="$(find ${CORE_PATH[${nextcore,,}]} -type d \( -name *BIOS* -o -name *Eu* -o -name *Other* -o -name *VGM* -o -name *NES2PCE* -o -name *FDS* -o -name *SPC* -o -name Unsupported \) -prune -false -o -name *.${CORE_EXT[${nextcore,,}]} | shuf -n 1)"
			romname=$(basename "${rompath}")
		else # Use ZIP
			romname=$("${partunpath}" "$(find ${CORE_PATH[${nextcore,,}]} -maxdepth 1 -type f \( -iname "*.zip" \) | shuf -n 1)" -i -r -f ${CORE_EXT[${nextcore,,}]} --rename /tmp/Extracted.${CORE_EXT[${nextcore,,}]})
			# Partun returns the actual rom name to us so we need a special case here
			romname=$(basename "${romname}")
			rompath="/tmp/Extracted.${CORE_EXT[${nextcore,,}]}"
		fi
	else
		rompath="$(find ${CORE_PATH[${nextcore,,}]} -type f \( -iname *.${CORE_EXT[${nextcore,,}]} \) | shuf -n 1)"
		romname=$(basename "${rompath}")
	fi

	if [ -z "${rompath}" ]; then
		core_error "${nextcore}" "${rompath}"
	else
		load_core "${nextcore}" "${rompath}" "${romname%.*}" "${1}"
	fi
}

load_core() 	# load_core core /path/to/rom name_of_rom (countdown)
{	
	echo -n "Next up on the "
	echo -ne "\e[4m${CORE_PRETTY[${1,,}]}\e[0m: "
	echo -e "\e[1m${3}\e[0m"
	echo "${3} (${1})" > /tmp/SAM_Game.txt

	if [ "${4}" == "countdown" ]; then
		echo "Loading in..."
		for i in {5..1}; do
			echo "${i} seconds"
			sleep 1
		done
	fi

	"${mbcpath}" load_rom ${1^^} "${2}" > /dev/null 2>&1
}

core_error() # core_error core /path/to/ROM
{
	if [ ${romloadfails} -lt ${coreretries} ]; then
		declare -g romloadfails=$((romloadfails+1))
		echo "ERROR: Failed ${romloadfails} times. No valid game found for core: ${1} rom: ${2}"
		echo "Trying to find another rom..."
		next_core ${1}
	else
		echo "ERROR: Failed ${romloadfails} times. No valid game found for core: ${1} rom: ${2}"
		echo "ERROR: Core ${1} is blacklisted!"
		declare -g corelist=("${corelist[@]/${1}}")
		echo "List of cores is now: ${corelist[@]}"
		declare -g romloadfails=0
		next_core
	fi	
}

disable_bootrom()
{
	if [ "${disablebootrom}" == "Yes" ]; then
		if [ -d "${misterpath}/Bootrom" ]; then
			mount --bind /mnt "${misterpath}/Bootrom"
		fi
		if [ -f "${misterpath}/Games/NES/boot0.rom" ]; then
			touch /tmp/brfake
			mount --bind /tmp/brfake ${misterpath}/Games/NES/boot0.rom
		fi
		if [ -f "${misterpath}/Games/NES/boot1.rom" ]; then
			touch /tmp/brfake
			mount --bind /tmp/brfake ${misterpath}/Games/NES/boot1.rom
		fi
	fi
}


# ======== ARCADE MODE ========
build_mralist()
{
	# If no MRAs found - suicide!
	find "${mrapath}" -maxdepth 1 -type f \( -iname "*.mra" \) &>/dev/null
	if [ ! ${?} == 0 ]; then
		echo "The path ${mrapath} contains no MRA files!"
		loop_core
	fi
	
	# This prints the list of MRA files in a path,
	# Cuts the string to just the file name,
	# Then saves it to the mralist file.
	
	# If there is an empty exclude list ignore it
	# Otherwise use it to filter the list
	if [ ${#mraexclude[@]} -eq 0 ]; then
		find "${mrapath}" -maxdepth 1 -type f \( -iname "*.mra" \) | cut -c $(( $(echo ${#mrapath}) + 2 ))- >"${mralist}"
	else
		find "${mrapath}" -maxdepth 1 -type f \( -iname "*.mra" \) | cut -c $(( $(echo ${#mrapath}) + 2 ))- | grep -vFf <(printf '%s\n' ${mraexclude[@]})>"${mralist}"
	fi
}

load_core_arcade()
{
	# Get a random game from the list
	mra="$(shuf -n 1 ${mralist})"

	# If the mra variable is valid this is skipped, but if not we try 10 times
	# Partially protects against typos from manual editing and strange character parsing problems
	for i in {1..10}; do
		if [ ! -f "${mrapath}/${mra}" ]; then
			mra=$(shuf -n 1 ${mralist})
		fi
	done

	# If the MRA is still not valid something is wrong - suicide
	if [ ! -f "${mrapath}/${mra}" ]; then
		echo "There is no valid file at ${mrapath}/${mra}!"
		return
	fi

	echo -n "Next up at the "
	echo -ne "\e[4m${CORE_PRETTY[${nextcore,,}]}\e[0m: "
	echo -e "\e[1m$(echo $(basename "${mra}") | sed -e 's/\.[^.]*$//')\e[0m"
	echo "$(echo $(basename "${mra}") | sed -e 's/\.[^.]*$//') (${nextcore})" > /tmp/SAM_Game.txt

	if [ "${1}" == "countdown" ]; then
		echo "Loading quarters in..."
		for i in {5..1}; do
			echo "${i} seconds"
			sleep 1
		done
	fi

  # Tell MiSTer to load the next MRA
  echo "load_core ${mrapath}/${mra}" > /dev/MiSTer_cmd
}


# ======== MAIN ========
echo "Starting up, please wait a minute..."
parse_ini									# Overwrite default values from INI
disable_bootrom									# Disable Bootrom until Reboot 
build_mralist								# Generate list of MRAs
init_data										# Setup data arrays
parse_cmdline ${@}					# Parse command line parameters for input
there_can_be_only_one "$$" "${0}"	# Terminate any other running Attract Mode processes
echo "Let Mortal Kombat begin!"
loop_core										# Let Mortal Kombat begin!
exit
