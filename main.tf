#this is the module development for roboshop-infra-user, Here we are developing all resources and calling from there 


resource "aws_vpc" "main" {
  cidr_block       = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support = var.enable_dns_support

  tags = merge(
    var.common_tags,
    {
        Name = var.project_name
    },
    var.vpc_tags
  )
}

#IG

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
        Name = var.project_name
    },
    var.igw_tags
  )
}

#subnets 

resource "aws_subnet" "public" {

  count = length(var.public_subnet_cidr)
  map_public_ip_on_launch = true
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr[count.index]
  availability_zone = local.azs[count.index]


  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-public-${local.azs[count.index]}"
    },
    
  )
}

resource "aws_subnet" "private" {

  count = length(var.private_subnet_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr[count.index]
  availability_zone = local.azs[count.index]


  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-private-${local.azs[count.index]}"
    },
    
  )
}

resource "aws_subnet" "database" {

  count = length(var.database_subnet_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.database_subnet_cidr[count.index]
  availability_zone = local.azs[count.index]


  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-database-${local.azs[count.index]}"
    },
    
  )
}




#Elastic IP, NAT gateway --> this need to attach to private & DB instances to connect with internet securely

resource "aws_eip" "eip" {
    domain   = "vpc"
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.common_tags,
    {
        Name = var.project_name
    },
    var.nat_gateway_tags
    
  )

  depends_on = [aws_internet_gateway.gw]
}


 #route tables & Routes

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-public"
    },
    var.public_route_table_tags
    
  )
}

#private routetables and routes

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }


  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-private"
    },
    var.private_route_table_tags
    
  )
}




resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }


  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-database"
    },
    var.database_route_table_tags
    
  )
}

resource "aws_route_table_association" "public" {
  
  count = length(var.public_subnet_cidr)
  subnet_id = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  
  count = length(var.private_subnet_cidr)
  subnet_id = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  
  count = length(var.database_subnet_cidr)
  subnet_id = element(aws_subnet.database[*].id, count.index)
  route_table_id = aws_route_table.database.id
}

#db subnet group 


resource "aws_db_subnet_group" "roboshop" {
    name = "roboshop"
    subnet_ids = aws_subnet.database[*].id

    tags = merge(
      var.common_tags,
      {
        Name = var.project_name
      },
      var.db_subnet_group_tags

    )
  
}





