# vim: set sw=2 ts=2 softtabstop=2 expandtab tw=120 :
_           = require 'underscore'
assert      = require 'assert'
async      = require 'async'
Clever      = require "#{__dirname}/../index"
QueryStream = require "#{__dirname}/../lib/querystream"
Understream = require 'understream'

describe "require('clever/mock') [API KEY] [MOCK DATA DIR]", ->
  before ->
    @clever = require("#{__dirname}/../mock") 'api key', "#{__dirname}/mock_data"

  it "supports streaming GETs", (done) ->
    clever = Clever {token: 'DEMO_TOKEN'}
    stream = clever.Student.find().stream()
    assert (stream instanceof QueryStream), 'An incorrect object was returned'
    items = 0
    stream.on 'data', (obj) ->
      assert obj, 'Failed to get an item'
      items++
    stream.on 'end', () ->
      assert items, 'No items found'
      done()

  it "supports count", (done) ->
    @clever.Student.find().count().exec (err, count) ->
      assert.ifError err
      assert.equal count, require("#{__dirname}/mock_data/students").length
      done()

  it "supports non-streaming GETs", (done) ->
    @clever.Student.find().exec (err, data) ->
      assert.ifError err
      assert.deepEqual _(data).invoke('toJSON'), require("#{__dirname}/mock_data/students")
      done()

  it "deep copies data", (done) ->
    async.waterfall [
      (cb_wf) =>
        @clever.Student.find().exec (err, students) ->
          assert.ifError err
          name = students[0].get 'name'
          assert.equal name.first, "John"
          name.first = 'WRONG NAME'
          cb_wf()
      (cb_wf) =>
        @clever.Student.find().exec (err, students) ->
          assert.ifError err
          name = students[0].get 'name'
          assert.equal name.first, "John"
          cb_wf()
    ], done


  it "supports GETting properties", (done) ->
    @clever.Student.find().exec (err, students) => # TODO: get findOne working
      students[0].properties (err, data) =>
        assert.ifError err
        assert.deepEqual data, _(require("#{__dirname}/mock_data/studentproperties")).findWhere({student: students[0].get('id')}).data
        done()

  it "supports deep copies of properties", (done) -> # depends on previous test
    async.waterfall [
      (cb_wf) =>
        @clever.Student.find().exec (err, students) =>
          students[0].properties (err, data) =>
            assert.ifError err
            assert.equal data.foo, "bar"
            data.foo = 'WRONG FOO'
            cb_wf()
      (cb_wf) =>
        @clever.Student.find().exec (err, students) =>
          students[0].properties (err, data) =>
            assert.ifError err
            assert.equal data.foo, "bar"
            cb_wf()
    ], done

  it "supports PUTting properties", (done) ->
    @clever.Student.find().exec (err, students) =>
      assert.ifError err
      students[1].properties {foo: 'baz'}, (err, data) =>
        assert.ifError err
        assert.deepEqual data, {foo: 'baz'}
        @clever.Student.find().exec (err, students) =>
          assert.ifError err
          students[1].properties (err, data) =>
            assert.deepEqual data, {foo: 'baz'}
            done()

  describe 'findById', ->
    _.each ['51a5a56f4867bbdf51054055', '51a5a56f4867bbdf51054054'], (id) ->
      it "finds a student", (done) ->
        @clever.Student.findById id, (err, student) ->
          assert.ifError err
          assert.equal student.get('id'), id
          done()

    it "returns undefined if the id is not found", (done) ->
      @clever.Student.findById 'not an existing id', (err, student) ->
        assert.ifError err
        assert not student, 'Expected student to be undefined'
        done()
