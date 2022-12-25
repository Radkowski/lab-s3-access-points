import boto3
import yaml
import logging 
import sys

def read_input_args():
    if len(sys.argv) == 2:
        if (sys.argv[1]).lower() == ('--list'):
            return (['List'])
        elif (sys.argv[1]).lower() == ('--get'):
            return (['Get'])
        elif (sys.argv[1]).lower() == ('--put'):
            return (['Put'])
    print(len(sys.argv))
    return (['List','Get','Put'])
        

def return_session(service, profile):
    if profile !='':
        session = boto3.Session(profile_name=profile)
    else:
        session = boto3.Session()
    return (session.client(service))  


def who_am_i(profile):
    return (return_session("sts",profile).get_caller_identity()['Arn'])


def read_config():
    with open('config.yaml', 'r') as file:
        configuration = yaml.safe_load(file)
    return (configuration['Config'])


def ls_bucket(bucket,profile,verbose=False):
    try:
        response = return_session("s3",profile).list_objects_v2(Bucket=bucket)
        return True
    except Exception as e:
        if verbose: 
            logging.error('Error at %s', 'division', exc_info=e)
        return False


def get_object(bucket,profile,verbose=False):
    try:
        response = return_session("s3",profile).get_object(Bucket=bucket,Key='testfile.txt')
        return True
    except Exception as e:
        if verbose: 
            logging.error('Error at %s', 'division', exc_info=e)
        return False


def put_object(bucket,profile,verbose=False):
    try:
        response = return_session("s3",profile).put_object(Bucket=bucket,Key='putsomefile.txt')
        return True
    except Exception as e:
        if verbose: 
            logging.error('Error at %s', 'division', exc_info=e)
        return False


def trim_bucket_list():
    app_config = (read_config())
    max_size = len (app_config['s3_bucket'])
    trim_names =  [
        app_config['s3_bucket'],
        app_config['external_s3_bucket'][:max_size-5]+'(...)',
        app_config['accesspoints']['internal'][:max_size-5]+'(...)',
        app_config['accesspoints']['external'][:max_size-5]+'(...)' 
        ]
    full_names =  [
        app_config['s3_bucket'], 
        app_config['external_s3_bucket'], 
        app_config['accesspoints']['internal'], 
        app_config['accesspoints']['external'] ]
    return {
        "trim_names": trim_names,
        "full_names": full_names
    }


def trim_profiles_list():
    app_config = (read_config())
    configured_profiles = app_config['Profiles']
    if app_config['IncludeLocalCredentials']:
        configured_profiles.append('')
    return configured_profiles


def testing_buckets(action,verbose=False):
    functions = {
    "List": ls_bucket,
    "Get": get_object,
    "Put": put_object,
    }
    all_locations = trim_bucket_list()
    int_count = 0
    for buckets in (all_locations['full_names']):
        for x in trim_profiles_list():
            if x == '':
                    print(action,' ',all_locations['trim_names'][int_count],'\t using default/instance profile \t', end= ' ')
            else:
                    print(action,' ',all_locations['trim_names'][int_count],'\t using profile ',x,' \t', end= ' ')
            if functions[action](buckets,x,verbose):
                print('ACCESS GRANTED')
            else:
                    print('Access Denied')  
        int_count+=1
    return 0
   


for x in read_input_args():
    testing_buckets(x,False)
    print('**************************')




