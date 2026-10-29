import importlib.util, pathlib, unittest
spec = importlib.util.spec_from_file_location('pipeline', pathlib.Path(__file__).resolve().parents[1] / 'src/pipeline.py')
p = importlib.util.module_from_spec(spec); spec.loader.exec_module(p)
class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.segments = [{'id': 1, 'timestamp': '00:00:12', 'text': 'Alex will deliver the report by Friday.'}]
        self.item = {'kind':'deliverable','text':'Deliver the report','owner':'Alex','due':'Friday','segment_id':1,'quote':'Alex will deliver the report by Friday.'}
    def test_evidence_and_owner(self):
        good,bad=p.validate({'items':[self.item]}, self.segments)
        self.assertFalse(bad); self.assertEqual(good[0]['timestamp'],'00:00:12')
    def test_invented_quote_rejected(self):
        good,bad=p.validate({'items':[dict(self.item,quote='Alex will launch the rocket.')]}, self.segments)
        self.assertFalse(good); self.assertEqual(len(bad),1)
    def test_invented_owner_and_date_removed(self):
        good,_=p.validate({'items':[dict(self.item,owner='Bob',due='Monday')]}, self.segments)
        self.assertEqual(good[0]['owner'],'not specified'); self.assertEqual(good[0]['due'],'not specified')
    def test_bad_segment_and_malformed_fail(self):
        good,bad=p.validate({'items':[dict(self.item,segment_id=99), {'text':'bad'}]},self.segments)
        self.assertFalse(good); self.assertEqual(len(bad),2)
        with self.assertRaises(ValueError): p.validate({'unexpected':[]},self.segments)
    def test_chunk_coverage_long_unicode(self):
        source=[{'id':i,'text':'会议记录 '*1500,'timestamp':'00:00:00'} for i in range(1,5)]
        groups=list(p.chunks(source))
        self.assertGreater(len(groups),4)
        for s in source:
            # Chunk overlap must not lose any source text.
            parts=[]
            for group in groups:
                for fragment in group:
                    if fragment['id']==s['id']: parts.append(fragment['text'])
            self.assertGreaterEqual(sum(len(x) for x in parts),len(s['text']))
            self.assertTrue(all(len(x.encode())<=1500 for x in parts))
    def test_explicit_blocker_is_not_decision(self):
        segments=[{'id':1,'timestamp':'00:00:00','text':'The release is blocked by approval.'}]
        good,_=p.validate({'items':[dict(self.item,kind='decision',quote=segments[0]['text'])]},segments)
        self.assertEqual(good[0]['kind'],'blocker')
    def test_empty_notes(self):
        self.assertEqual(p.validate({'items':[]}, self.segments),([],[]))
    def test_timestamp(self): self.assertEqual(p.timestamp(3671000),'01:01:11')
if __name__=='__main__': unittest.main()
