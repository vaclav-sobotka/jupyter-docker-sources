#! /bin/bash

#$1 - LOCAL_FOLDER
#$2 - BUCKET_SUBFOLDER
#$3 - DATA_FOLDER
#$4 - BUCKET_NAME
function processTuple {
    NEW_FOLDER="$3/$1";
    mkdir -p "$NEW_FOLDER";
    aws s3 sync --region eu-central-1 s3://"$4"/"$2" "$NEW_FOLDER";
    return 0;
}

function checkArgs {
	if [ -z "$MAPPINGS" ]; then
		echo "MAPPINGS parameter was not set when running 'docker run'! Terminating the startup!";
		exit 1;
	fi
	if [ -z "$NB_USER" ]; then
		echo "USER parameter was not set when running 'docker run'! Terminating the startup!";
		exit 1;
	fi
	if [ -z "$BUCKET_NAME" ]; then
		echo "BUCKET_NAME parameter was not set when running 'docker run'! Terminating the startup!";
		exit 1;
	fi
	if [ -z "$AWS_ACCESS_KEY_ID" ]; then
		echo "AWS_ACCESS_KEY_ID env variable was not set. Terminating the startup!";
		exit 1;
	fi
	if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
		echo "AWS_SECRET_ACCESS_KEY env variable was not set. Terminating the startup!";
		exit 1;	
	fi
	if [ -z "$PASSWORD" ]; then
		echo "PASSWORD env variable was not set. Terminating the startup!";
		exit 1;
	fi
}

checkArgs;

DATA_FOLDER="/home/$NB_USER/Roaming";
MAPPING_FILE="/root/.mappings";

mkdir -p "$DATA_FOLDER";
#erase all potential content, if the file existed
> "$MAPPING_FILE";

#process MAPPINGS - MAPPINGS is a string of tuples devided with ;
#a single tuple has the following format:    <container-dir-name>:<bucket-subdirectory>
for TUPLE in $(IFS=';'; echo $MAPPINGS); do
    TOKENS=(${TUPLE//:/ });

    if [ ${#TOKENS[@]} != 2 ]; then
        echo "Invalid pair localDir:bucketSubfolder !";
        exit 1;
    fi

    LOCAL_FOLDER=${TOKENS[0]};
    BUCKET_SUBFOLDER=${TOKENS[1]};

	#check directory name contains only permitted characters
    if ! [[ "$LOCAL_FOLDER" =~ ^([A-Za-z0-9_.-])+$ ]]; then
        echo "Local folder name $LOCAL_FOLDER contains character(s) which is/are not permitted!";
        exit 1;
    fi

	#append mapping to mapping file
	echo "$DATA_FOLDER/$LOCAL_FOLDER:$BUCKET_NAME/$BUCKET_SUBFOLDER" >> "$MAPPING_FILE";

	#create a new directory under /home/<USER>/Roaming and fill it with content of respective bucket subfolder
	processTuple "$LOCAL_FOLDER" "$BUCKET_SUBFOLDER" "$DATA_FOLDER" "$BUCKET_NAME";
done

chown -R "$NB_USER:$NB_USER" "$DATA_FOLDER"

BASHRC_PATH="/home/$NB_USER/.bashrc";
SYNC_UP_ALIAS='alias sync-up="sudo -E /root/jupyter-docker-sources/sync-mappings-up"';
SYNC_DOWN_ALIAS='alias sync-down="sudo -E /root/jupyter-docker-sources/sync-mappings-down"';

if [ -z $(grep "$SYNC_UP_ALIAS" "$BASHRC_PATH") ]; then
	echo "$SYNC_UP_ALIAS" >> "$BASHRC_PATH";
fi

if [ -z $(grep "$SYNC_DOWN_ALIAS" "$BASHRC_PATH") ]; then
	echo "$SYNC_DOWN_ALIAS" >> "$BASHRC_PATH";
fi

start-notebook.sh --NotebookApp.password="$PASSWORD";
