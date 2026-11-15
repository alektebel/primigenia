"""Known drainage topology and binary-dump rejection, no naturalness tautologies."""
import importlib.util
import math
import struct
import tempfile
import unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('terrain_metrics',Path(__file__).parents[1]/'tools/terrain/metrics.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class Metrics(unittest.TestCase):
    def test_known_strahler_tree(self):
        n=8; dirs=[-1]*64;flow=[0.0]*64
        # Four first-order tributaries form two second-order streams then one third.
        edges={(1,1):(2,2),(3,1):(2,2),(2,2):(3,3),
               (5,1):(5,2),(6,1):(5,2),(5,2):(4,3),(4,3):(3,3),(3,3):(3,4)}
        for (x,y),(a,b) in edges.items():
            dirs[y*n+x]=list(zip(m.DX,m.DY)).index((a-x,b-y))
            flow[y*n+x]=1/64;flow[b*n+a]=1/64
        result=m.metrics({'n':n,'size':8,'height':list(range(64)),
                          'flow':flow,'dir':dirs,'seed':1,'flags':0},.5)
        self.assertEqual(result['segments'],{1:4,2:2,3:1})
        self.assertAlmostEqual(result['rb'],2)
        self.assertAlmostEqual(result['hypsometric'],.5)
    def test_constant_height(self):
        result=m.metrics({'n':8,'size':8,'height':[2]*64,'flow':[1/64]*64,
                          'dir':[-1]*64,'seed':1,'flags':0},100)
        self.assertIsNone(result['rb']);self.assertIsNone(result['hack'])
        self.assertEqual(result['hypsometric'],0)
    def test_dump_validation(self):
        header=struct.pack('<8sIIifI',b'CPTER10\0',1,1,8,8.,0)
        blob=header+struct.pack('<192f',*([1.]*192))+struct.pack('<64b',*([-1]*64))
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'map.bin';p.write_bytes(blob)
            self.assertEqual(m.load_dump(p)['n'],8)
            for bad in (b'bad',blob[:-1],blob+b'?',blob[:8]+struct.pack('<I',99)+blob[12:],blob[:-1]+b'\x08'):
                p.write_bytes(bad)
                with self.assertRaises(ValueError):m.load_dump(p)
    def test_distance(self):
        self.assertEqual(m.dist_range(.4,.5,.6),.5-.4)
        self.assertEqual(m.dist_range(4,3,5),0)
        self.assertIsNone(m.dist_range(None,3,5))
if __name__=='__main__':unittest.main()
