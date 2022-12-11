provider "aws" {
  region = "us-east-1"
  access_key = "AKIAY5KPQUBWBJPB37RF"
  secret_key = "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"

}



# 1. Create vpc

resource "aws_vpc" "mainVpc" {
    cidr_block = "10.0.0.0/16"
  
}


#2. Create Internet Gateway

resource "aws_internet_gateway" "mainGateway" {
    vpc_id = aws_vpc.mainVpc.id

    tags = {
      Name = "mainGateway"
    }
  
}

# 3. Create Custom Route Table

resource "aws_route_table" "mainRouteTable" {

    vpc_id = aws_vpc.mainVpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.mainGateway.id
    }
    route {
        ipv6_cidr_block        = "::/0"
        gateway_id = aws_internet_gateway.mainGateway.id
    }

    tags = {
        Name = "Prod"
    }
  
}
#4. Create a Subnet



resource "aws_subnet" "mainSubnet" {
    vpc_id = aws_vpc.mainVpc.id
    cidr_block = "10.0.1.0/24"

    tags = {
        Name = "mainSubnet"
    }
  
}



# 5. Associate subnet with Route Table

resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.mainSubnet.id
    route_table_id = aws_route_table.mainRouteTable.id
  
}

#6. Create Security Group to allow port 22,80,443

resource "aws_security_group" "allow-web" {

    name = "allow_web_traffic"
    description = "Allow_web_traffic"
    vpc_id = aws_vpc.mainVpc.id

    ingress {
        description = "HTTPS"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description =  "Http"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"  #"-1" means any protocol is allowed
        cidr_blocks = ["0.0.0.0/0"] 
    }

    tags = {
        Name = "allow_web"
    }
}
#7. Create a network interface with an ip in the subnet that was created in step 4


  


resource "aws_network_interface" "main_Network_Interface" {
    subnet_id = aws_subnet.mainSubnet.id
    private_ips = ["10.0.1.100"]
    security_groups = [aws_security_group.allow-web.id]

}
# 8. Assign an elastic IP to the network interface created in step 7

resource "aws_eip" "EIP" {
    vpc = true
    network_interface = aws_network_interface.main_Network_Interface.id
    associate_with_private_ip = "10.0.1.100"
    depends_on = [aws_internet_gateway.mainGateway]
  
}

#Using output function to check the Ips

output "server_public_ip" {
    value = aws_eip.EIP.public_ip
}

output "private_ip" {
    value = aws_instance.mainInstance.private_ip
  
}
#9. Create Ubuntu server and install/enable apache2

resource "aws_instance" "mainInstance" {
    ami = "ami-0574da719dca65348"
    instance_type = "t2.micro"
    key_name = "main-key"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.main_Network_Interface.id
    }

    user_data = <<-EOF
                sudo apt update -y
                sudo apt install apache2 -y
                sudo ystemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF
    
    tags = {
      Name = "my-web-server"
    }


  
}