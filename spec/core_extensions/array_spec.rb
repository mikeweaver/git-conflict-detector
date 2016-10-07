require 'spec_helper'

describe 'CoreExtensions::Array' do

  before(:all) do
    Array.include CoreExtensions::Array
  end

  describe 'include_regex?' do

    it 'can include? regular expressions for array of regular expression strings' do
      array = ['.*world', '.*moon']

      expect(array.include_regex?('hello_world')).to be_truthy
      expect(array.include_regex?('hello_moon')).to be_truthy
      expect(array.include_regex?('hello_space')).to be_falsey
    end

    it 'can include? regular expressions for array of regular expressions' do
      array = [/.*world/, /.*moon/]

      expect(array.include_regex?('hello_world')).to be_truthy
      expect(array.include_regex?('hello_moon')).to be_truthy
      expect(array.include_regex?('hello_space')).to be_falsey
    end

    it 'can accept regex options for array of regular expression strings' do
      array = ['.*world', '.*moon']

      expect(array.include_regex?('hello_WORLD', regexp_options=Regexp::IGNORECASE)).to be_truthy
    end
  end

  describe 'reject_regex' do

    it 'can reject strings that match a regular expression' do
      array = ['hello_world', 'hello_moon']

      expect(array.reject_regex(/.*world/)).to match_array(['hello_moon'])
      expect(array.reject_regex(/hello.*/)).to match_array([])
      expect(array.reject_regex(/nomatch.*/)).to match_array(['hello_world', 'hello_moon'])
    end

    it 'can reject strings that match an array of regular expressions' do
      array = ['hello_world', 'hello_moon']

      expect(array.reject_regex([/.*world/])).to match_array(['hello_moon'])
      expect(array.reject_regex([/.*world/, /.*moon/])).to match_array([])
      expect(array.reject_regex([/hello.*/])).to match_array([])
      expect(array.reject_regex([/nomatch.*/])).to match_array(['hello_world', 'hello_moon'])
    end

    it 'can reject strings that match an array of regular expression strings' do
      array = ['hello_world', 'hello_moon']

      expect(array.reject_regex(['.*world'])).to match_array(['hello_moon'])
      expect(array.reject_regex(['.*world', '.*moon'])).to match_array([])
      expect(array.reject_regex(['hello.*'])).to match_array([])
      expect(array.reject_regex(['nomatch.*'])).to match_array(['hello_world', 'hello_moon'])
    end

    it 'can reject regex options for array of regular expression strings' do
      array = ['hello_WORLD', 'hello_moon']

      expect(array.reject_regex(['.*world'], regexp_options=Regexp::IGNORECASE)).to match_array(['hello_moon'])
    end
  end

  describe 'select_regex' do

    it 'can select strings that match a regular expression' do
      array = ['hello_world', 'hello_moon']

      expect(array.select_regex(/.*world/)).to match_array(['hello_world'])
      expect(array.select_regex(/hello.*/)).to match_array(['hello_world', 'hello_moon'])
      expect(array.select_regex(/nomatch.*/)).to match_array([])
    end

    it 'can select strings that match an array of regular expressions' do
      array = ['hello_world', 'hello_moon']

      expect(array.select_regex([/.*world/])).to match_array(['hello_world'])
      expect(array.select_regex([/.*world/, /.*moon/])).to match_array(['hello_world', 'hello_moon'])
      expect(array.select_regex([/hello.*/])).to match_array(['hello_world', 'hello_moon'])
      expect(array.select_regex([/nomatch.*/])).to match_array([])
    end

    it 'can select strings that match an array of regular expression strings' do
      array = ['hello_world', 'hello_moon']

      expect(array.select_regex(['.*world'])).to match_array(['hello_world'])
      expect(array.select_regex(['.*world', '.*moon'])).to match_array(['hello_world', 'hello_moon'])
      expect(array.select_regex(['hello.*'])).to match_array(['hello_world', 'hello_moon'])
      expect(array.select_regex(['nomatch.*'])).to match_array([])
    end

    it 'can accept regex options for array of regular expression strings' do
      array = ['hello_WORLD', 'hello_moon']

      expect(array.select_regex(['.*world'], regexp_options=Regexp::IGNORECASE)).to match_array(['hello_WORLD'])
    end
  end
end


