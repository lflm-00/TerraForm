/*** Load Balances para aplicacion que realiza deciisones de ruteo a nivel de la aplicacion
enrutamientos basados en el path , enrutar request en distintos puertos
en nuestro caso lo ahremos interno en la vpc , no podremos acceder desde internet , solo desde la vpc ***/
resource "aws_lb" "app_alb" {
  name = "${local.name_prefix}-app-ALB" // Nombre del recurso
  internal = true // Acceso interno , solo puede ser utilizado dentro de nuestra VPC
  load_balancer_type = "application" //Balancear la carga de nuestras aplicaciones
  idle_timeout = 600 // Tiempo permitido para el Load balancer
  security_groups = [aws_security_group.APP_ALB_SG.id] // Grupo de seguridad solo permite request en el port 80 ,443 tcp
  subnets = [aws_subnet.PRUEBA_PUBLIC_SUBNET.id ,aws_subnet.PRUEBA_PRIVATE_SUBNET.id ] // subredes , la privada y la publica
                                                                                      // que tenemos en 2 availability zones
  enable_deletion_protection = false // argumento para que no pueda ser eliminado por accidente 
                                    // lo dejamos en false por temas de pruebas

  tags = merge({
      "Name" = "${local.name_prefix}-app-ALB"
  },
  local.default_tags,
  )
}

/*** Target Group podemos asignar ec2 o relacionar con un auto-scaling group ,
va redireccionar todos los request de nuestro webapp ***/
resource "aws_lb_target_group" "APP_TG"{
 name = "${local.name_prefix}-APP-TG"
 port = "80" // Redirecciona al puerto 80 de las ec2 que pertenezcan a este grupo
 protocol = "HTTP" // Si fuera prd importante el ssh "HTTPS"
 vpc_id = aws_vpc.PRUEBA_VPC.id // Asignamos la VPC mediante iterpolacion
 target_type = "instance" // Podemos redireccionar a otro flujo ejem: IP
 tags = merge({
      "Name" = "${local.name_prefix}-app-LB-TG"
  },
  local.default_tags,
  )
  lifecycle{
    create_before_destroy = true // Si queremos hacer un cambio en este target group primero se crea el nuevo y luego se elimina este
    ignore_changes = [name] // Para evitar recrear este target en caso de que se cambie el nombre sin querer
                           // 
  }

  health_check {
     // Para verificar que nuestro servicio este disponible enviando request cada intervalo de tiempo
     interval = 30 // Intervalo de segundos 
     healthy_threshold = 2 // para saber que el recurso esta healthy debe responder al menos 2 veces
     unhealthy_threshold = 2 // Para determinar que no recibimos respuesta al recibir 2 request fallidos
     timeout = 5 // Para una respuesta fallida 5 segundos de timeout
     matcher = "200" // Para considerar un request correcto debe tener respuesta de codigo 200
  }
}

/*** Listener por donde definimos que el load balancer recibe request ***/

resource "aws_lb_listener" "APP_http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn // Ierpolacion para relacionar el load balancer con el lb listener
  port = "80"
  protocol = "HTTP"


  default_action{
      type = "forward"
      target_group_arn = aws_lb_target_group.APP_TG.arn
  }
}