require 'spec_helper'

describe 'Array' do

  before(:all) do
    Array.include CoreExtensions::Array
  end

  describe 'include_regex?' do

    it 'can include? regular expressions for array of regular expression strings' do
      array = ['.*world', '.*moon']

      expect(array.include_regex?('hello_world')).to eq(true)
      expect(array.include_regex?('hello_moon')).to eq(true)
      expect(array.include_regex?('hello_space')).to eq(false)
    end

    it 'can include? regular expressions for array of regular expressions' do
      array = [/.*world/, /.*moon/]

      expect(array.include_regex?('hello_world')).to eq(true)
      expect(array.include_regex?('hello_moon')).to eq(true)
      expect(array.include_regex?('hello_space')).to eq(false)
    end
  end

  describe 'reject_regex' do

    it 'can reject strings that match a regular expression' do
      array = ['hello_world', 'hello_moon']

      expect(array.reject_regex(/.*world/)).to eq(['hello_moon'])
      expect(array.reject_regex(/hello.*/)).to eq([])
      expect(array.reject_regex(/nomatch.*/)).to eq(['hello_world', 'hello_moon'])
    end

    it 'can reject strings that match an array of regular expressions' do
      array = ['hello_world', 'hello_moon']

      expect(array.reject_regex([/.*world/])).to eq(['hello_moon'])
      expect(array.reject_regex([/.*world/, /.*moon/])).to eq([])
      expect(array.reject_regex([/hello.*/])).to eq([])
      expect(array.reject_regex([/nomatch.*/])).to eq(['hello_world', 'hello_moon'])
    end

    it 'can reject strings that match an array of regular expression strings' do
      array = ['hello_world', 'hello_moon']

      expect(array.reject_regex(['.*world'])).to eq(['hello_moon'])
      expect(array.reject_regex(['.*world', '.*moon'])).to eq([])
      expect(array.reject_regex(['hello.*'])).to eq([])
      expect(array.reject_regex(['nomatch.*'])).to eq(['hello_world', 'hello_moon'])
    end
  end

  describe 'select_regex' do

    it 'can select strings that match a regular expression' do
      array = ['hello_world', 'hello_moon']

      expect(array.select_regex(/.*world/)).to eq(['hello_world'])
      expect(array.select_regex(/hello.*/)).to eq(['hello_world', 'hello_moon'])
      expect(array.select_regex(/nomatch.*/)).to eq([])
    end

    it 'can select strings that match an array of regular expressions' do
      array = ['hello_world', 'hello_moon']

      expect(array.select_regex([/.*world/])).to eq(['hello_world'])
      expect(array.select_regex([/.*world/, /.*moon/])).to eq(['hello_world', 'hello_moon'])
      expect(array.select_regex([/hello.*/])).to eq(['hello_world', 'hello_moon'])
      expect(array.select_regex([/nomatch.*/])).to eq([])
    end

    it 'can select strings that match an array of regular expression strings' do
      array = ['hello_world', 'hello_moon']

      expect(array.select_regex(['.*world'])).to eq(['hello_world'])
      expect(array.select_regex(['.*world', '.*moon'])).to eq(['hello_world', 'hello_moon'])
      expect(array.select_regex(['hello.*'])).to eq(['hello_world', 'hello_moon'])
      expect(array.select_regex(['nomatch.*'])).to eq([])
    end
  end
end


