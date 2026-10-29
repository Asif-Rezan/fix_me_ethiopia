"""Extract reference content into a native-widget specification; no HTML is shipped."""
from html.parser import HTMLParser
from pathlib import Path
import json
class Parser(HTMLParser):
 def __init__(self):
  super().__init__(); self.root={'tag':'root','children':[]}; self.stack=[self.root]
 def handle_starttag(self, tag, attrs):
  n={'tag':tag,'attrs':dict(attrs),'children':[]}; self.stack[-1]['children'].append(n)
  if tag not in ['br','meta','img','input','hr','link']: self.stack.append(n)
 def handle_endtag(self, tag):
  for i in range(len(self.stack)-1,0,-1):
   if self.stack[i]['tag']==tag: self.stack=self.stack[:i]; break
 def handle_data(self,data):
  if data.strip(): self.stack[-1]['children'].append({'tag':'text','text':data})
def find(n,tag):
 if n['tag']==tag:return n
 for c in n.get('children',[]):
  r=find(c,tag)
  if r:return r
src=Path('/Users/asif/Downloads/FixMe_Ethiopia_All_45_Screens')
screens=[]
for f in sorted((src/'screens').glob('*.html')):
 p=Parser();p.feed(f.read_text()); main=find(p.root,'main')
 screens.append({'id':int(f.name[:2]),'name':f.stem[3:],'nav':'withnav' in main['attrs'].get('class',''),'children':main['children']})
Path('assets/data/screens.json').write_text(json.dumps(screens,ensure_ascii=False,indent=2))
Path('docs/design_mapping.md').write_text('# Design mapping\n\nNative screen routes mirror all supplied references. The JSON contains content and semantic layout nodes, not HTML or screenshots.\n\n'+ '\n'.join(f"- `/screen/{s['id']}` — `{s['id']:02}_{s['name']}.png`" for s in screens))
