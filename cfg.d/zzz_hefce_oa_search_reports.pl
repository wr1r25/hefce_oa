$c->{datasets}->{eprint}->{search}->{hefce_report} = 
{
	search_fields => [
		{ meta_fields => [ "title" ] },
		{ meta_fields => [ "creators_name" ] },
		{ meta_fields => [ "eprint_status" ] },
		{ meta_fields => [ "date" ] },
		{ meta_fields => [ "hoa_date_acc" ] },
		{ meta_fields => [ "subjects" ] },
		{ meta_fields => [ "ispublished" ] },
		{ meta_fields => [ "divisions" ] },
		{ meta_fields => [ "publication" ] },
		{ meta_fields => [ "hoa_gold" ] },
		{ meta_fields => [ "hoa_override" ] },
	],
	order_methods => {
		"byyear" 	 => "-date/creators_name/title",
		"byyearoldest"	 => "date/creators_name/title",
		"byname"  	 => "creators_name/-date/title",
		"bytitle" 	 => "title/creators_name/-date"
	},
	default_order => "byyear",
	show_zero_results => 1,
};
