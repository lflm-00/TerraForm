resource "aws_vpc" "PRUEBA_VPC" { // VPC es una red privada en la que montaremos toda la infra
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true // para habilitar todas las maquinas dentro de esta vpc y utilizar de DNS los nameservers de aws
  tags = merge({
    "Name" = "${local.name_prefix}-VPC"
    },
    local.default_tags,
  )
}

resource "aws_internet_gateway" "PRUEBA_IGW" { // Conectar a internet a nuestros recursos
  vpc_id = aws_vpc.PRUEBA_VPC.id               // accedemos al id de la vpc por iterpolacion
  tags = merge({
    "Name" = "${local.name_prefix}-IGW"
    },
    local.default_tags,
  )
}

/*** Sub Redes 2 ... 1 publica 1 privada
la publica tendra recursos con acceso a internet directo e ips publicas
la privada tendrà recursos acceso a internet con network acces traslation ***/

//publica - availability_zone A
resource "aws_subnet" "PRUEBA_PUBLIC_SUBNET" {
  map_public_ip_on_launch = true                     // Asignar ip publicos por defecto
  availability_zone       = element(var.az_names, 0) // manejamos 2 zonas para tener un control en caso de caida
  vpc_id                  = aws_vpc.PRUEBA_VPC.id
  cidr_block              = element(var.subnet_cidr_blocks, 0) //Dominio de ips
  tags = merge({
    "Name" = "${local.name_prefix}-SUBNET-AZ-A"
    },
    local.default_tags,
  )
}

// Privada -  availability_zone B
resource "aws_subnet" "PRUEBA_PRIVATE_SUBNET" {
  map_public_ip_on_launch = false
  availability_zone       = element(var.az_names, 1)
  vpc_id                  = aws_vpc.PRUEBA_VPC.id
  cidr_block              = element(var.subnet_cidr_blocks, 1)
  tags = merge({
    "Name" = "${local.name_prefix}-SUBNET-AZ-B"
    },
    local.default_tags,
  )
}

/*** Elastic IP para adjuntar a nuestro natGateway ... el ip que utilizaran las maquinas
que no tengan ip publico para acceder a internet **/

resource "aws_eip" "APP_EIP" {
  vpc = true
}



/*** NatGateway para conectar recursos a internet sin que tengan ip publica
para acceder a internet pero internet no puede verlos atraves del network addres traslation
***/

resource "aws_nat_gateway" "PRUEBA_NAT" {
  subnet_id     = aws_subnet.PRUEBA_PUBLIC_SUBNET.id // relacionamos el nat a la subred publica
  allocation_id = aws_eip.APP_EIP.id                 // punto de acceso para este nat ... en este caso publico 
  tags = merge({
    "Name" = "${local.name_prefix}-NGW"
    },
    local.default_tags,
  )
}

/*** un ruta publica para nuestra subnet publica ***/

resource "aws_route_table" "PRUEBA_PUBLIC_ROUTE" {
  vpc_id = aws_vpc.PRUEBA_VPC.id
  route {
    cidr_block = "0.0.0.0/0" // Cuando se asigne a una subred esta va poder enviar paquetes a  cualquier destino de la vpc         
    gateway_id = aws_internet_gateway.PRUEBA_IGW.id
  }
  tags = merge({
    "Name" = "${local.name_prefix}-PUBLIC-RT"
    },
    local.default_tags,
  )
}


/*** un ruta publica para nuestra subnet privada ***/
resource "aws_route_table" "PRUEBA_PRIVATE_ROUTE" {
  vpc_id = aws_vpc.PRUEBA_VPC.id // cualquier recurso que tenga asignada esta ruta prodrà enviar paquetes 
  // a cualquier direccion en nuestra infra
  route {
    cidr_block = "0.0.0.0/0" // Le creamos unra ruta especifica para el NatGertway para conectarse 
    //a internet utilizando una ip publica y traducir la direccion de paquetes a direccion privada
    nat_gateway_id = aws_nat_gateway.PRUEBA_NAT.id
  }
  tags = merge({
    "Name" = "${local.name_prefix}-PRIVATE-RT"
    },
    local.default_tags,
  )
}

/*** Endpoints para conectarnos con recursos de AWS 
en este caso tendremos un endpoint a un S3 (bucket) ***/

resource "aws_vpc_endpoint" "PRUEBA_S3_ENDPOINT" {                                                    // Este Endpoint es de tipo Gateway
  vpc_id          = aws_vpc.PRUEBA_VPC.id                                                             // adjuntamos la vpc 
  service_name    = "com.amazonaws.${var.aws_region}.s3"                                              // el nombre del endpoint para la region en que se crea la infra
  route_table_ids = [aws_route_table.PRUEBA_PUBLIC_ROUTE.id, aws_route_table.PRUEBA_PRIVATE_ROUTE.id] // asignamos las subredes
  // de esta forma los recursos de S3 llegaràn a 
  // nuestras subredes
}

/*** Asociamos nuestras tablas de enrutamiento con nuestras
subredes para redireccionar los paquetes que lleguen ***/

resource "aws_route_table_association" "PUBLIC_ASSO" {
  route_table_id = aws_route_table.PRUEBA_PUBLIC_ROUTE.id // Asociamos el id de la tabla de enrrutamiento publica
  subnet_id      = aws_subnet.PRUEBA_PUBLIC_SUBNET.id     // Asociamos el id de la subnet publica 
}

resource "aws_route_table_association" "PRIVATE_ASSO" {
  route_table_id = aws_route_table.PRUEBA_PRIVATE_ROUTE.id
  subnet_id      = aws_subnet.PRUEBA_PRIVATE_SUBNET.id
}

/*** medidas de seguridad a la vpc para restringir 
accesos a ciertos puertos con Network Acces Control List***/

resource "aws_network_acl" "PRUEBA_NACL" {
  vpc_id     = aws_vpc.PRUEBA_VPC.id                                                     // Relacionamos la VPC por iterpolacion
  subnet_ids = [aws_subnet.PRUEBA_PUBLIC_SUBNET.id, aws_subnet.PRUEBA_PRIVATE_SUBNET.id] // Definimos la subnet a las
  // queremos aplicar este acces control list
  ingress { // Definimos las reglas de ingreso
    protocol   = "tcp"
    rule_no    = 110
    action     = "deny"      // Negamos el acceso
    cidr_block = "0.0.0.0/0" // Para cualquier IP denegamos el acceso por el puerto tcp ip Telnet
    from_port  = 23          // Puerto Telnet poco seguro
    to_port    = 23
  }

  ingress { // Definimos las reglas de ingreso
    protocol   = "tcp"
    rule_no    = 32766       // Tiene presedencial , aplica las reglas en orden
    action     = "allow"     // Permitimos el acceso de cualquier ip
    cidr_block = "0.0.0.0/0" // Para cualquier IP permitimos el acceso por cualquier puerto
    from_port  = 0
    to_port    = 0
  }

  egress { // Definimos las reglas de egreso
    protocol   = "tcp"
    rule_no    = 110
    action     = "deny"      // Negamos el egreso
    cidr_block = "0.0.0.0/0" // Para cualquier IP denegamos que salga cualquier cosa por el puerto tcp ip Telnet
    from_port  = 23          // Puerto Telnet poco seguro
    to_port    = 23
  }

  egress { // Definimos las reglas de ingreso
    protocol   = "tcp"
    rule_no    = 32766       // Tiene presedencial , aplica las reglas en orden
    action     = "allow"     // Permitimos el egreso de cualquier ip 
    cidr_block = "0.0.0.0/0" // Para cualquier IP permitimos el egreso por cualquier puerto
    from_port  = 0
    to_port    = 0
  }

  tags = merge({
    "Name" = "${local.name_prefix}-NACL"
    },
    local.default_tags,
  )
}

/*** Security Groups funcionan como firewalls 
a nivel de recurso (mas especificos) , es iperativo en produccion tener security groups segun
los recursos que tengamos y los puertos que abramos e ip que permitamos ***/

// 
resource "aws_security_group" "APP_ALB_SG" {
  vpc_id = aws_vpc.PRUEBA_VPC.id // Relacionamos la VPC
  name   = "${local.name_prefix}-ALB-SG"

  ingress {              // Definimos las reglas de ingreso
    from_port       = 80 // Web request habilitamos puerto 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.APP_SG.id]
  }

  ingress { // Definimos las reglas de ingreso
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.APP_SG.id]
  }



  egress {          // Definimos las reglas de ingreso
    from_port   = 0 // Por cualquier puerto 
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] // A cualquier IP
  }

  tags = merge({
    "Name" = "${local.name_prefix}-SG_LB"
    },
    local.default_tags,
  )
}

/*** Security Group para nuestros recursos 
o servicios que no sea allow balance ***/

resource "aws_security_group" "APP_SG" {
  vpc_id = aws_vpc.PRUEBA_VPC.id // Relacionamos la VPC
  name   = "${local.name_prefix}-SG-APP"

  ingress {              // Definimos las reglas de ingreso
    from_port       = 22 //  habilitamos puerto 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_vpc.PRUEBA_VPC.cidr_block] // Solo pueden acceder a estos puertos desde estas ips
  }

  ingress {                // Definimos las reglas de ingreso
    from_port       = 3389 // Puerto Remote Desktop
    to_port         = 3389
    protocol        = "tcp"
    security_groups = [var.vpc_cidr] // Variables o iterpolacion para definir la vpc
  }

  ingress { // Definimos las reglas de ingreso
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_vpc.PRUEBA_VPC.cidr_block] // Variables o iterpolacion para definir la vpc
  }



  egress {          // Definimos las reglas de ingreso
    from_port   = 0 // Por cualquier puerto 
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] // A cualquier IP
  }

  tags = merge({
    "Name" = "${local.name_prefix}-SG"
    },
    local.default_tags,
  )
}

