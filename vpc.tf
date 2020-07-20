provider "aws"{
  region = "ap-south-1"
  profile= "honipiple"
}
#vpc
resource "aws_vpc" "hpvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true


  tags = {
    Name = "hp_vpc"
  }
}

#subnet
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.hpvpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1a"


  tags = {
    Name = "hp_subnet1"
  }
}
resource "aws_subnet" "private" {
    vpc_id = aws_vpc.hpvpc.id


    cidr_block = "192.168.0.0/24"
    availability_zone = "ap-south-1b"


  tags = {
    Name = "hp_subnet2"

   }
}

#internet gateway
resource "aws_internet_gateway" "mygw" {
  vpc_id = aws_vpc.hpvpc.id


  tags = {
    Name = "hp_gw"
   }
}
#rout table
resource "aws_route_table" "my_route_table1" {
  vpc_id = aws_vpc.hpvpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mygw.id
  }


  tags = {
    Name = "hp_routetable"
  }
}
resource "aws_route_table_association" "route_table_association1" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.my_route_table1.id
}

#EIP for nat gateway
resource "aws_eip" "nat" {
  vpc      = true
  depends_on = [aws_internet_gateway.mygw,]

}
#nat gateway with EIP
resource "aws_nat_gateway" "hpnatgw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on = [aws_internet_gateway.mygw,]
 
 tags = {
    Name = "hp_NAT_GW"
  }
}

#nat gateway associate with private subnat
resource "aws_route_table" "my_route_table2" {
  vpc_id = aws_vpc.hpvpc.id


  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.hpnatgw.id
  }


  tags = {
    Name = "hp_routetable_for_natgw"
 }
}
#create security group
resource "aws_security_group" "mywebsecurity" {
  name        = "my_web_security"
  description = "Allow http,ssh,icmp"
  vpc_id      = aws_vpc.hpvpc.id


  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ALL ICMP - IPv4"
    from_port   = -1    
    to_port     = -1
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks =  ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "myweb_sg"
  }
}
#security group for mysql Aurora for database
resource "aws_security_group" "mysqlsecurity" {
  name        = "my_sql_security"
  description = "Allow mysql"
  vpc_id      = aws_vpc.hpvpc.id


  ingress {
    description = "MYSQL/Aurora"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = ["${aws_security_group.mywebsecurity.id}"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks =  ["0.0.0.0/0"]
  }
  
  tags = {
   Name = "mysql_sg"  
 }
}
#security group for allow ssh
resource "aws_security_group" "mybastionsecurity" {
  name        = "my_bastion_security"
  description = "Allow ssh for bastion host"
  vpc_id      = aws_vpc.hpvpc.id




  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks =  ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "mybastion_sg"

   }
}
#security group for mysqlserver
resource "aws_security_group" "mysqlserversecurity" {
  name        = "my_sql_server_security"
  description = "Allow mysql ssh for bastion host only"
  vpc_id      = aws_vpc.hpvpc.id


  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.mybastionsecurity.id}"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks =  ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "mysqlserver_sg"
}
}
# creating instance for wordpress
resource "aws_instance" "wordpress" {
  ami           = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = ["${aws_security_group.mywebsecurity.id}"]
  key_name = "key123"
  availability_zone = "ap-south-1a"


  tags = {
    Name = "wordpress"
  }


}
 
#creating instance for mysql
resource "aws_instance" "mysql" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private.id
  vpc_security_group_ids = ["${aws_security_group.mysqlsecurity.id}","${aws_security_group.mysqlserversecurity.id}"]
  key_name = "key123"
  availability_zone = "ap-south-1b"


 tags = {
    Name = "mysql"
  }


}

#creating instance for bastionhost
resource "aws_instance" "bastionhost" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = ["${aws_security_group.mybastionsecurity.id}"]
  key_name = "key123"
  availability_zone = "ap-south-1a"


  tags = {
    Name = "mybastionhost"
  }
}

