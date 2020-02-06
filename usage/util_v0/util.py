#!/usr/bin/env python

import os

import json
import argparse
import logging
from datetime import datetime

from keystoneauth1 import loading
from keystoneauth1 import session

from keystoneclient import client as keystone_client
from novaclient import client as nova_client
from cinderclient import client as cinder_client

from flask import Flask
from flask import jsonify

def get_keystone_creds():
    #try:
    f = open('/path/to/openrc.json', 'r')
    #except IOError:
    #    return
    #else:
    openrc = json.load(f)

    d = {}
    d['OS_USERNAME'] = openrc['OS_USERNAME']
    d['OS_PASSWORD'] = openrc['OS_PASSWORD']
    d['OS_AUTH_URL'] = openrc['OS_AUTH_URL']
    d['OS_PROJECT_NAME'] = openrc['OS_PROJECT_NAME']
    d['OS_REGION_NAME'] = openrc['OS_REGION_NAME']
    d['OS_PROJECT_DOMAIN_NAME'] = openrc['OS_PROJECT_DOMAIN_NAME']
    d['OS_USER_DOMAIN_NAME'] = openrc['OS_USER_DOMAIN_NAME']
    d['OS_IDENTITY_API_VERSION'] = openrc['OS_IDENTITY_API_VERSION']
    d['OS_INTERFACE'] = openrc['OS_INTERFACE']
    return d

def getUtilizationV0():
    auth=get_keystone_creds()

    loader = loading.get_plugin_loader('password')
    keystone = loader.load_from_options(auth_url=auth['OS_AUTH_URL'],
                                    username=auth['OS_USERNAME'],
                                    password=auth['OS_PASSWORD'],
                                    project_name=auth['OS_PROJECT_NAME'],
                                    user_domain_name=auth['OS_USER_DOMAIN_NAME'],
                                    project_domain_name=auth['OS_PROJECT_DOMAIN_NAME']
                                   )

    sess = session.Session(auth=keystone)

    nova = nova_client.Client(2.1, session=sess)

    # Docs stink
    # get field names from json output of openstack command line
    # or look here: nova/api/openstack/compute/hypervisors.py
    # or here: nova/objects/compute_node.py

    hvs=[]
    hv_total={}
    hv_total['vcpus']=0
    hv_total['vcpus_used']=0
    hv_total['memory_mb']=0
    hv_total['memory_mb_used']=0
    hv_total['free_ram_mb']=0
    hv_total['running_vms']=0
    hv_total['hypervisors']=0

    for nc in nova.hypervisors.list(detailed=True):
        hv={}
        hv_total['hypervisors']+=1
        hv['id']=nc.id
        hv['hypervisor_hostname']=nc.hypervisor_hostname
        hv['vcpus']=nc.vcpus
        hv_total['vcpus']+=hv['vcpus']
        hv['vcpus_used']=nc.vcpus_used
        hv_total['vcpus_used']+=hv['vcpus_used']
        hv['memory_mb']=nc.memory_mb
        hv_total['memory_mb']+=hv['memory_mb']
        hv['memory_mb_used']=nc.memory_mb_used
        hv_total['memory_mb_used']+=hv['memory_mb_used']
        hv['free_ram_mb']=nc.free_ram_mb
        hv_total['free_ram_mb']+=hv['free_ram_mb']
        hv['running_vms']=nc.running_vms
        hv_total['running_vms']+=hv['running_vms']
        hvs.append(hv)


    #print json.dumps(hvs,indent=2)
    hv_total['vcpus_percent'] =  int(100*hv_total['vcpus_used']/hv_total['vcpus'])
    hv_total['memory_percent'] = int(100*hv_total['memory_mb_used']/hv_total['memory_mb'])
    #print json.dumps(hv_total,indent=2)
    ts = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    hv_total['ts']=ts
    return hv_total

def getProjectUsage():
    auth=get_keystone_creds()

    loader = loading.get_plugin_loader('password')
    keystone = loader.load_from_options(auth_url=auth['OS_AUTH_URL'],
                                    username=auth['OS_USERNAME'],
                                    password=auth['OS_PASSWORD'],
                                    project_name=auth['OS_PROJECT_NAME'],
                                    user_domain_name=auth['OS_USER_DOMAIN_NAME'],
                                    project_domain_name=auth['OS_PROJECT_DOMAIN_NAME']
                                   )

    sess = session.Session(auth=keystone)

    # Projects
    keystone = keystone_client.Client(session=sess,interface=auth['OS_INTERFACE'])

    projects = keystone.projects.list()
    pros={}

    for project in projects:
       pro={}
       pro['name']=project.name
       pro['description']=project.description
       pros[project.id]=pro

    # Nova
    nova = nova_client.Client(2.1, session=sess)

    # Flavors
    flavors={}
    for flavor in nova.flavors.list():
        flv={}
        #print flavor.id,flavor.name,flavor.vcpus,flavor.ram
        flv['name']=flavor.name
        flv['vcpus']=flavor.vcpus
        flv['ram']=flavor.ram
        flv['disk']=flavor.disk
        flavors[flavor.id]=flv

    #VMS
    search_opts = {'all_tenants': 1}
    vms=[]

    for server in nova.servers.list(detailed=True, search_opts=search_opts):
        # Charge for all others
        if server.status == "SHELVED_OFFLOADED" or server.flavor['id'] not in flavors.keys() or server.tenant_id not in pros.keys():
            continue
        vm={}
        vm['id']=server.id
        vm['name']=server.name
        vm['project_id']=server.tenant_id
        vm['flavor_id']=server.flavor['id']
        # Must exist
        vm['project_name']=pros[vm['project_id']]['name']
        # Must exist
        vm['vcpus']=flavors[vm['flavor_id']]['vcpus']
        vm['ram']=flavors[vm['flavor_id']]['ram']
        if server.image:
            # Seems to be the only way to figure out if we are volume backed or not
            vm['disk'] = flavors[vm['flavor_id']]['disk']
        vms.append(vm)

    # Roll up
    usages={}
    usages['ts']=datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    usages['projects']={}

    # Cinder

    cinder = cinder_client.Client(2, session=sess)
    vols={}
    for volume in cinder.volumes.list(detailed=True, search_opts=search_opts):
        vsize = volume.size
        vproj = getattr(volume,'os-vol-tenant-attr:tenant_id')
        proj_name=pros[vproj]['name']
        if vproj not in usages['projects']:
            usage={}
            usage['project_name']=proj_name
            usage['vcpus']=0
            usage['ram']=0
            usage['vms']=0
            usage['vol_size']=0
            usage['vols']=0
            usages['projects'][vproj]=usage
        else:
            usage=usages['projects'][vproj]

        usage['vol_size']+=vsize
        usage['vols']+=1

    for vm in vms:
        if vm['project_id'] not in usages['projects']:
            usage={}
            usage['project_name']=vm['project_name']
            usage['vcpus']=0
            usage['ram']=0
            usage['vms']=0
            usage['vol_size']=0
            usage['vols']=0
            usages['projects'][vm['project_id']]=usage
        else:
            usage=usages['projects'][vm['project_id']]

        ephemeral = vm.get('disk',0)
        if ephemeral > 0:
            usage['vol_size']+=ephemeral
            usage['vols']+=1

        usage['vcpus']+=vm['vcpus']
        usage['ram']+=vm['ram']
        usage['vms']+=1

    return usages

app = Flask(__name__)

@app.route('/utilization/v0/')
def utilization_v0():
    resp = getUtilizationV0()
    return jsonify(resp)

@app.route('/utilization/byproject/v0/')
def project_utilization_v0():
    resp = getProjectUsage()
    return jsonify(resp)

@app.route('/')
def foo():
    return "foo"

@app.route('/utilization/v1/')
def utilization_v1():
    ts = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    resp = {'ts': ts, 'vcpus_percent': 68}
    return jsonify(resp)

if __name__ == "__main__":
    app.run(host='128.205.41.11', port=5500)
