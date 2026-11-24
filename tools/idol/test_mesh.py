"""CPU integration checks. Analytic Gaussians are fixtures, never Idol evidence."""
import json
import struct
from pathlib import Path
import numpy as np
import pytest
from plyfile import PlyData, PlyElement
from mesh import load_splats, extract_mesh, export_asset, quaternion_matrices


def fixture(path, scale=(.18,.12,.08), rotation=(1,0,0,0), opacity=4):
    names=['x','y','z','f_dc_0','f_dc_1','f_dc_2','opacity','scale_0','scale_1','scale_2','rot_0','rot_1','rot_2','rot_3']
    v=np.zeros(1,dtype=[(n,'f4') for n in names])
    for n,x in zip(names,[0,0,0,.4,.2,0,opacity,*np.log(scale),*rotation]):v[n]=x
    PlyData([PlyElement.describe(v,'vertex')]).write(path)
    return path


def read_glb(path):
    data=path.read_bytes(); magic,version,size=struct.unpack_from('<4sII',data)
    assert (magic,version,size)==(b'glTF',2,len(data))
    length,kind=struct.unpack_from('<I4s',data,12); assert kind==b'JSON'
    return json.loads(data[20:20+length])


def test_anisotropic_opacity_surface_is_closed(tmp_path):
    s=load_splats(fixture(tmp_path/'fixture.ply'))
    mesh,report=extract_mesh(s,resolution=40,level=.2,budget=4000)
    assert mesh.is_watertight
    assert mesh.extents[0]>mesh.extents[1]>mesh.extents[2]
    assert 0<len(mesh.faces)<=4000
    assert np.isfinite(mesh.vertices).all()
    assert report['retained_gaussians']==1


def test_rotation_changes_surface_orientation(tmp_path):
    s=load_splats(fixture(tmp_path/'fixture.ply',rotation=(2**-.5,0,0,2**-.5)))
    mesh,_=extract_mesh(s,resolution=40,level=.2,budget=3000)
    assert mesh.extents[1]>mesh.extents[0]>mesh.extents[2]


def test_quaternion_is_normalized():
    assert np.allclose(quaternion_matrices(np.array([[2.,0,0,0]])),np.eye(3)[None])


def test_ordinary_point_cloud_rejected(tmp_path):
    v=np.zeros(1,dtype=[('x','f4'),('y','f4'),('z','f4')]);p=tmp_path/'points.ply'
    PlyData([PlyElement.describe(v,'vertex')]).write(p)
    with pytest.raises(ValueError,match='3DGS'):load_splats(p)


@pytest.mark.parametrize('opacity',[float('nan'),-100])
def test_nonfinite_or_empty_rejected(tmp_path,opacity):
    with pytest.raises(ValueError):load_splats(fixture(tmp_path/'fixture.ply',opacity=opacity))


def test_budgets_and_invalid_surface_fail_closed(tmp_path):
    s=load_splats(fixture(tmp_path/'fixture.ply'))
    for kwargs in [dict(resolution=4),dict(level=1),dict(budget=0)]:
        with pytest.raises(ValueError):extract_mesh(s,**kwargs)
    with pytest.raises(ValueError,match='surface'):extract_mesh(s,resolution=32,level=.999999)


def test_glb_both_styles_and_regions(tmp_path):
    s=load_splats(fixture(tmp_path/'fixture.ply'))
    m,r=extract_mesh(s,resolution=40,level=.2,budget=120)
    assert len(m.faces)<=120
    toon=tmp_path/'toon.glb'; export_asset(m,s,toon,style='toon',region='keratin')
    d=read_glb(toon); assert 'KHR_materials_unlit' in d['extensionsUsed']
    assert d['materials'][0]['name']=='Palette C baked toon'
    assert d['meshes'][0]['primitives'][0]['attributes']['COLOR_0']>=0
    for region,name in [('skin','Tidal teal skin'),('keratin','Plum keratin'),('eye','Obsidian eyes'),('membrane','Coral membrane')]:
        p=tmp_path/(region+'.glb');export_asset(m,s,p,style='physical',region=region)
        d=read_glb(p);assert d['materials'][0]['name']==name
        assert d['materials'][0]['pbrMetallicRoughness']['metallicFactor']==0
    with pytest.raises(ValueError):export_asset(m,s,tmp_path/'bad.glb',style='wrong',region='skin')
