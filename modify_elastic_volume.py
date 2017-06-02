def lambda_handler(event, context):
  import boto3
  import math
  import json

  client = boto3.client('ec2')
  raw_json = event['Records'][0]['Sns']['Message']
  details = json.loads(raw_json)
  dimensions = details['Trigger']['Dimensions']

  filesystem = ""
  instance_id = ""
  for dimension in dimensions:
      if dimension['name'] == "Filesystem":
          filesystem = dimension['value']
      if dimension['name'] == "InstanceId":
          instance_id = dimension['value']

  response = client.describe_instances(
      InstanceIds=[
          instance_id
      ]
  )

  devices = response['Reservations'][0]['Instances'][0]['BlockDeviceMappings']
  volume = ''

  for device in devices:
      print(device['DeviceName'])
      print(filesystem[:-1])
      if device['DeviceName'] == filesystem[:-1]:
          volume = device['Ebs']['VolumeId']
  print(volume)
  percent_increase = 0.10

  print("Querying current volume size for " + volume + " ...")
  response = client.describe_volumes(
      VolumeIds=[
          volume
      ]
  )

  size = response['Volumes'][0]['Size']
  print("Volume size is currently: " + str(size) + " GB")
  increase = math.ceil(percent_increase * size)
  new_size = int(size + increase)
  print("New size: " + str(new_size) + " GB")

  response = client.modify_volume(
      VolumeId=volume,
      Size=new_size
  )

  print(response)
