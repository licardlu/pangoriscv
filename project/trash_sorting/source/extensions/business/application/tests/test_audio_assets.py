import pathlib,re,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
PLATFORM=ROOT/'firmware/platform.c'
I2S=ROOT/'rtl/i2s_tx.sv'
class AudioAssetContract(unittest.TestCase):
 def test_external_i2s_music_assets_are_registered(self):
  text=PLATFORM.read_text(encoding='utf-8')
  self.assertRegex(text,r'\bAUDIO_ASSET_COUNT\s+7')
  for name in ('MUSIC0  WAV','MUSIC1  WAV','MUSIC2  WAV'):
   self.assertIn(name,text)
  self.assertRegex(text,r'audio_cache\s*\[\s*AUDIO_ASSET_COUNT\s*\]')
  self.assertIn('current_audio_asset >= 5',text)
  self.assertIn('asset(0, 5) << 28',text)
  i2s=I2S.read_text(encoding='utf-8')
  self.assertIn('12.288MHz',i2s)
  self.assertIn('output reg bclk,lrclk,sdout',i2s)
if __name__=='__main__': unittest.main()
