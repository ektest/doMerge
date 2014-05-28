#Tempt variables and files
tempRevList="revisions.list"
tempRevUSList="revisions.uniquesortedlist"
tempSvnMergeRevs="svn_merge_revs.list"
my_path=''
repo_file=''
repo_path_file=''
REPO=''
repo_path=''
metadataFiles=''
conflictsFiles=''
dryrun=""

handleSequence(){
	# Is parameter zero length
    if [ -z "$1" ]; then
		echo "Parameter is zero length or No Parameter passed" 
    else
		#echo "Param is \"$1\"."
		first=$(echo $1 | awk -F'-' '{print $1}')
		last=$(echo $1 | awk -F'-' '{print $2}')
    fi
    
    if [[  $last -le $first ]]; then
    	echo "Error: Illegal Revision Sequence: $first-$last"
    	clearFiles
    	exit
	else
		#Writing the revisions in the sequence
		while [  $first -le $last ]; do
        	echo $first >> $tempRevList
			let first=first+1 
		done
	fi
}

getRepoDirectory(){
	#Determine REPO root and directory
	my_path=$(dirname $0)
	repo_file="$my_path/repo_url.txt"

	if ! [ -f "$repo_file" ] ; then
		echo "ERROR : File not found : $repo_file"
		exit
	fi

	repo_path_file="$my_path/repo_path.txt"

	if ! [ -f "$repo_path_file" ] ; then
    	echo "ERROR : File not found : $repo_path_file"
    	exit
	fi

	REPO=$(cat "$repo_file")
	repo_path=$(cat "$repo_path_file")

	if [ "$REPO" == "" ] ; then
		echo "ERROR : Unable to determine repository root"
		exit
	fi
}

sortRemoveDuplicates(){
	#Sorting and Removing the duplicates
	cat $tempRevList | sort -n -u >  $tempRevUSList
	#echo "-" >> $tempRevUSList
}

createSVNCommand(){
	#Creating array
	array=($(cat $tempRevUSList))
	counter=1
	tempt=''
	currentItem=''
	nextItem=''

	#echo "Array items:"
	for index in ${!array[*]}
	do
		nextIndex=$((index+1))
		#echo "currentItem: ${array[$index]} ||| nextItem: ${array[$nextIndex]}"
		#printf "%4d: %s\n" $index ${array[$index]}
		
		currentItem=${array[$index]}
		nextItem=${array[$nextIndex]}
		#let currentItem=currentItem+1
		
		if [[ "$((currentItem+1))" == "$nextItem" ]]; then
			#echo "HERE currentItem = $currentItem ---> $((currentItem+1))"
			if [[ "$tempt" == "" ]]; then
				tempt=$currentItem
			fi
			
			let counter=counter+1
			continue
		else
			if [[ "$counter" == "1" ]]; then
				echo "-c $currentItem" >> $tempSvnMergeRevs
				tempt=''
			else
				#echo "TEMPT= $tempt ||| currentItem = $currentItem ---> $((currentItem+1))"
				let tempt=tempt-1
				let counter=tempt+counter
				echo "-r $tempt:$counter" >> $tempSvnMergeRevs
				counter=1
				tempt=''
			fi
		fi
	done
}

clearFiles(){
	#cat $tempRevList
	rm $tempRevList
	
	#cat $tempRevUSList
	rm $tempRevUSList
	
	#echo `cat $tempSvnMergeRevs |tr '\n', ' '`
	rm $tempSvnMergeRevs
}

#Adding dry-run functionality to doMerge
if [ "$1" == '--dry-run' ] ; then
	dryrun='--dry-run'
	shift
	echo "--dry-run ENABLED!"
else
	echo "--dry-run DISABLED!"
fi

#Reading command-line args passed to the script
while ! [ "$1" == "" ]; do
	rev=$1

	#strip 'r' from the first character
	if [[ "$rev" =~ ^r[0-9]+$ ]]; then
		rev=`echo $rev | cut -b2-`
echo "new rev=" $rev
	fi
	
	#Finding Sequence in command-line args passed to the script
	if  [[ "$rev" =~ ^[0-9]+-[0-9]+$ ]]; then
        	#echo "Sequence Revision: $rev"
        	handleSequence $rev
        	shift
        	continue
	else
		#Validating Revision that comes from command-line args passed to the script
		if ! [[ "$rev" =~ ^[0-9]+$ ]]; then
			echo "Error: Illegal Revision: $rev"
			exit
		fi
	fi

	echo $rev >> $tempRevList
	shift
done

#Sorting and removing the duplicates
sortRemoveDuplicates

#Determining REPO root and directory
getRepoDirectory

#Creating SVN MERGE command
createSVNCommand

#Run SVN Merge Command
echo "### Merging from $REPO/$repo_path to $my_path ###"
echo "Running: svn merge `cat $tempSvnMergeRevs |tr '\n', ' '` $REPO/$repo_path ."
if [[ "$dryrun" == "" ]]; then
	svn merge `cat $tempSvnMergeRevs |tr '\n', ' '` $REPO/$repo_path .
else
	svn merge $dryrun `cat $tempSvnMergeRevs |tr '\n', ' '`$REPO/$repo_path 
fi

printf "\n"

#Run Status
echo "### STATUS ###"
svn status |grep -v '?'
printf "\n"

#Clearing the tempt files
clearFiles

printf "\n"
#Catch the conflict if exits
echo "### Conflicts: ###"
conflictsFiles=`svn status | grep -e '^[^C]{0,6}C'`

if  [[ "$conflictsFiles" == "" ]]; then
	echo "No Conflicts"
else
	echo "$conflictsFiles"
fi		
