/* ************************************************************************ */
/*																			*/
/*  Tora - Neko Application Server											*/
/*  Copyright (c)2008 Motion-Twin											*/
/*																			*/
/* This library is free software; you can redistribute it and/or			*/
/* modify it under the terms of the GNU Lesser General Public				*/
/* License as published by the Free Software Foundation; either				*/
/* version 2.1 of the License, or (at your option) any later version.		*/
/*																			*/
/* This library is distributed in the hope that it will be useful,			*/
/* but WITHOUT ANY WARRANTY; without even the implied warranty of			*/
/* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU		*/
/* Lesser General Public License or the LICENSE file for more details.		*/
/*																			*/
/* ************************************************************************ */
import neko.NativeString;
import Client.Code;

class ModNekoApi {

	public var client : Client;
	public var main : Void -> Void;

	public function new(client) {
		this.client = client;
	}

	function cgi_set_main( f : Void -> Void ) {
		main = f;
	}

	function get_host_name() {
		return NativeString.ofString(client.hostName);
	}

	function get_client_ip() {
		return NativeString.ofString(client.ip);
	}

	function get_uri() {
		return NativeString.ofString(client.uri);
	}

	function redirect( url : NativeString ) {
		headersNotSent("Redirection");
		client.sendMessage(CRedirect,NativeString.toString(url));
	}

	function set_return_code( code : Int ) {
		headersNotSent("Return code");
		client.sendMessage(CReturnCode,Std.string(code));
	}

	function get_client_header( header : NativeString ) {
		var c;
		var hl = NativeString.toString(header).toLowerCase();
		for( h in client.headers )
			if( h.k.toLowerCase() == hl )
				return NativeString.ofString(h.v);
		return null;
	}

	function get_params_string() {
		var p = client.getParams;
		if( p == null ) return null;
		return NativeString.ofString(p);
	}

	function get_post_data() {
		var p = client.postData;
		if( p == null ) return null;
		return NativeString.ofString(p);
	}

	function get_params() {
		return makeTable(client.params);
	}

	function cgi_get_cwd() {
		var path = client.file.split("/");
		if( path.length > 0 )
			path.pop();
		return NativeString.ofString(path.join("/")+"/");
	}

	function get_http_method() {
		return NativeString.ofString(client.httpMethod);
	}

	function set_header( header : NativeString, value : NativeString ) {
		headersNotSent(NativeString.toString(header));
		client.sendMessage(CHeaderKey,NativeString.toString(header));
		client.sendMessage(CHeaderValue,NativeString.toString(value));
	}

	function get_cookies() {
		var v : Dynamic = null;
		var c = get_client_header(NativeString.ofString("Cookie"));
		if( c == null ) return v;
		var c = NativeString.toString(c);
		var start = 0;
		var tmp = neko.Lib.bytesReference(c);
		while( true ) {
			var begin = c.indexOf("=",start);
			if( begin < 0 ) break;
			var end = begin + 1;
			while( true ) {
				var c = tmp.get(end);
				if( c == null || c == 10 || c == 13 || c == 59 )
					break;
				end++;
			}
			v = untyped __dollar__array(
				NativeString.ofString(c.substr(start,begin-start)),
				NativeString.ofString(c.substr(begin+1,end-begin-1)),
				v
			);
			if( tmp.get(end) != 59 || tmp.get(end+1) != 32 )
				break;
			start = end + 2;
		}
		return v;
	}

	function set_cookie( name : NativeString, value : NativeString ) {
		var buf = new StringBuf();
		buf.add(name);
		buf.add("=");
		buf.add(value);
		buf.add(";");
		client.sendMessage(CHeaderKey,"Set-Cookie");
		client.sendMessage(CHeaderAddValue,buf.toString());
	}

	function parse_multipart_data( onPart : NativeString -> NativeString -> Void, onData : NativeString -> Int -> Int -> Void ) {
		var bufsize = 1 << 16;
		client.sendMessage(CQueryMultipart,Std.string(bufsize));
		var filename = null;
		var buffer = haxe.io.Bytes.alloc(bufsize);
		while( true ) {
			var msg = client.readMessageBuffer(buffer);
			switch( msg ) {
			case CExecute:
				break;
			case CPartFilename:
				filename = buffer.sub(0,client.bytes).getData();
			case CPartKey:
				onPart( buffer.sub(0,client.bytes).getData(), filename );
				filename = null;
			case CPartData:
				onData( buffer.getData(), 0, client.bytes );
			case CPartDone:
			case CError:
				throw buffer.readString(0,client.bytes);
			default:
				throw "Unexpected "+msg;
			}
		}
	}

	function cgi_flush() {
		client.sendMessage(CFlush,"");
	}

	function get_client_headers() {
		return makeTable(client.headers);
	}

	function log_message( msg : NativeString ) {
		client.sendMessage(CLog,NativeString.toString(msg));
	}

	function tora_infos() {
		return Tora.inst.infos();
	}

	function tora_command(cmd,param) {
		return Tora.inst.command(cmd,param);
	}

	public function print( value : Dynamic ) {
		var str = NativeString.toString(untyped if( __dollar__typeof(value) == __dollar__tstring ) value else __dollar__string(value));
		client.headersSent = true;
		client.sendMessage(CPrint,str);
	}

	inline function headersNotSent( msg : String ) {
		if( client.headersSent ) throw NativeString.ofString("Cannot set "+msg+" : Headers already sent");
	}

	static function makeTable( list : Array<{ k : String, v : String }> ) : Dynamic {
		var v : Dynamic = null;
		for( h in list )
			v = untyped __dollar__array(NativeString.ofString(h.k),NativeString.ofString(h.v),v);
		return v;
	}

}