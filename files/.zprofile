export EC2_PRIVATE_KEY="$(ls $HOME/.ec2/pk-*.pem)"
export EC2_CERT="$(ls $HOME/.ec2/cert-*.pem)"
export AWS_CREDENTIALS_FILE="$HOME/.ec2/aws-credentials"
export LANG=en_NZ.utf8

[[ -d "/System/Library/Frameworks/JavaVM.framework/Home" ]] && export JAVA_HOME="/System/Library/Frameworks/JavaVM.framework/Home"
[[ -d "/usr/local/Cellar/ec2-api-tools/1.4.2.2/jars" ]] && export EC2_HOME="/usr/local/Cellar/ec2-api-tools/1.4.2.2/jars"
[[ -d "/usr/local/Cellar/ec2-ami-tools/1.3-45758/jars" ]] && export EC2_AMITOOL_HOME="/usr/local/Cellar/ec2-ami-tools/1.3-45758/jars"
