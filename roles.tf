/*** Empezaremos creando un data source 
para obtener la informacion de algunas politicas que ya estan definidas en aws ***/
data "aws_iam_policy" "AmazonS3FullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  
}
/*** Assume Role Policy un documento de politicas
para asumir el rol que nos permite asumir roles para nuestros ec2 ***/
data "aws_iam_policy_document" "assume_role" {
  statement{
    effect = "Allow" // Full permisos al servicio ec2 para asumir roles
    actions = [
      "sts:AssumeRole",
    ]
    principals{
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_iam_role" { //Rol
  name = "APP-IAM-ROLE" // Nombre del Rol
  assume_role_policy = data.aws_iam_policy_document.assume_role.json // documento de politica para asumir rol
                                                                    // Iterpolacion para acceder al source que retorna un JSON
  // Ya tenemos un rol que puede ser asumindo por el servico de ec2
}

/*** Para utilizar el Rol en ec2 tenemos que crear un instance profile
para relacionarlo con un rol para poder utilizarlo en las instancias ***/
resource "aws_iam_instance_profile" "app_instance_profile"{
    role = aws_iam_role.app_iam_role.name // Argumento el nombre del rol que queremos relacionar mediante irerpolacion
    name = "APP-INSTANCE-PROFILE"
}

/*** Asignamos la politica a nuestro rol mediante AWs Iam role policy attachment ***/
resource "aws_iam_role_policy_attachment" "app_s3_policy_attachment" {
  policy_arn = data.aws_iam_policy.AmazonS3FullAccess.arn // utilizamos iterpolacion del source iam policy 
  role = aws_iam_role.app_iam_role.name // adjuntamos el rol creado previamente 
}

/** CON ESTAS POLITICAS DEFINIDAS , ESTAMOS DICIENDO QUE NUESTRAS EC2
TENDRAN PERMISOS PARA ACCEDER A S3 DE MANERA COMPLETA ***/