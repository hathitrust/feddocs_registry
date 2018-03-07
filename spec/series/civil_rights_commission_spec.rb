require 'registry/source_record'
require 'registry/series/civil_rights_commission'
require 'json'
CRC = Registry::Series::CivilRightsCommission

describe 'CRC' do
  let(:src) { Class.new { extend CRC } }

  describe 'new' do
    it 'can create a new record without parsing/exploding' do
      sr = Registry::SourceRecord.new
      sr.org_code = 'miaahdl'
      sr.source = open(File.dirname(__FILE__) + '/data/civil_rights_commission.json').read
      expect(sr.enum_chrons[0]).to eq('NOT A REAL ENUMCHRON')
      expect(sr.holdings.values[0][0][:ec]).to eq('NOT A REAL ENUMCHRON')
      # PP.pp sr
    end
  end

  describe 'parse_ec' do
    it 'does nothing' do
      expect(src.parse_ec('1946, 1948, 1950')).to be_nil
    end
  end

  describe 'explode' do
  end

  describe 'sudoc_stem' do
    it 'has an sudocs field' do
      expect(CRC.sudoc_stem).to eq('CR')
    end
  end
end
