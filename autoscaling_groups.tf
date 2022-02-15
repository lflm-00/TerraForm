/*** Private keys 
Nos van a servir para loguearnos en las instancias ***/
resource "tls_private_key" "app_private_key" {
  algorithm = "RSA" // Tipo de algoritmo que se utilizarà para encriptar
  rsa_bits  = 4096  // Cantidad de bits para encriptar 
}

/*** Crearemos el KeyPair que utilizarà nuestras instancias 
si son en linux poder autenticarnos en ellas , si es en windows 
para descenriptar nuestro password ***/


resource "aws_key_pair" "generated_key" {
  key_name   = "APP-KEY"
  public_key = tls_private_key.app_private_key.public_key_openssh
}

/*** Utilizaremos un datasource para obetener la ultima imagen 
que utilizaran nuestras EC2 en el autosaling group ***/

data "aws_ami" "ubuntu" {
  most_recent = true       // Cuando filtre las imagenes, la imagen que queremos utilizar sea la mas reciente
  owners      = ["amazon"] // El fitro buscarà desde amazon 

  filter {
    name  = "name"                                 // filtraremos por nombre
    value = ["ubuntu-bionic-18.04-amd64-server-*"] // nombre de la distro a buscar  
  }
}

/*** Crearemos el launch configuration ,
 define las caracteristicas de las ec2 que se van a deployar ***/

resource "aws_launch_configuration" "app_launch_configuration" {
  name_prefix   = "${local.name_prefix}-APP-LC"
  image_id      = aws.aws_ami.ubuntu.image_id // imagen mas reciente (ubuntu ) previamente configurada
  instance_type = var.instance_type           // Tipo de instancia a deployar ... en este caso tenemos 
  // una gratuita definida en nuestras variables de desarrollo
  # user_data = ""

  associate_public_ip_address = false                                              // Queremos que no tenga ips publicas , serà privada sin acceso desde afuera
  iam_instance_profile        = aws_iam_instance_profile.app_instance_profile.name // Hemos creado anteriormente nuestro rol
  // En un paso anterior configuramos 
  //este recurso para que nuestras EC2 tengan full Acces a S3
  security_groups = [aws_security_group.APP_SG.id]      // Grupo creado para habilitar ciertos puertos de comunicacion
  key_name        = aws_key_pair.generated_key.key_name // keyName para autenticarnos en las maquinas en caso de ser necesario

  root_block_device {             // Definimos el volumen
    volume_size           = "60"  // 60 gigas
    volume_type           = "gp2" // Tipo de volumen , este es el mas usado 
    delete_on_termination = true  // Atributo para eliminar este block_device en caso de que estas Ec2 sean eliminadas , para evitar costos
  }

  lifecycle {
    create_before_destroy = true // Ete atributo es para eliminar este launch en caso de hacer algun cambio y se recree el launch 
  }
}

/*** AutoSacling Group , coleccion de EC2 ***/
resource "aws_autoscaling_group" "app_asg" {
  name_prefix = "${local.name_prefix}-APP"
  launch_configuration = aws_launch_configuration.app_launch_configuration.id
  vpc_zone_identifier = [aws_subnet.PRUEBA_PRIVATE_SUBNET.id,aws_subnet.PRUEBA_PUBLIC_SUBNET.id ]
  min_size = "2"
  max_size = "4"
  health_check_type = "EC2"
  lifecycle {
    create_before_destroy = true
  }
  tag = local.asg_default_tags
}
