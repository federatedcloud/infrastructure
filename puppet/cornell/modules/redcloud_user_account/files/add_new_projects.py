#!/usr/bin/python
import openstack
from subprocess import call

conn = openstack.connect(cloud='redcloud',region_name='ithaca')

cac_domain = conn.identity.find_domain("cac")
cac_groups = conn.identity.groups(domain_id=cac_domain.id)

#
# For each group in the domain, create a project and assign the group
# _member_ role if needed
#
for g in cac_groups:
	if conn.get_project(name_or_id=g.name, domain_id=cac_domain.id) == None:
		p = conn.create_project(name=g.name, description=g.name, domain_id=cac_domain.id)
		# Argh! Openstack SDK seems to unable assign users/groups to roles. 
		# So revert to openstack CLI
		cmd="openstack role add --group "+g.id+" --group-domain "+cac_domain.id+" --project "+p.id+" --project-domain "+cac_domain.id+" _member_"
		call(cmd, shell=True)
