#Use: Be in the folder in which you want to output the extraction of NE
#extractNERHip2.sh <path_to_wordtest_file>

sed 's/</ </g' $1 | sed 's/>/> /g' | awk '{
	pers=0;
	place=0;
	date=0;
	org=0;
	cardinal=0;
	persName="";
	placeName="";
	dateName="";
	orgName="";
	cardName="";
	for (i=2;i<=NF;i++){
		if($i=="<PER>"){
			if(pers==0){ 
			  pers=1;
			}
			persName="";
		}
		if($i=="</PER>"){
		   if(pers==1){
			pers=0;
			print persName" "$i  >> $1".txt";
			persName="";
		   }
		   else{
			$i="";
		   }
		}
		if($i=="<LOCATION>") {
			if(place==0){
			  place=1;
			}
			placeName="";
		}
		if($i=="</LOCATION>"){
		   if(place==1){
				place=0;
				print placeName" "$i >> $1".txt";
				placeName="";
		   }
			else{
				$i="";
		    }
		} 
		if($i=="<DATE>") {
			if(date==0){
			  date=1;
			}
			dateName="";	
		}
		if($i=="</DATE>"){
		   if(date==1){
			date=0;
			print dateName" "$i >> $1".txt";
			dateName="";
		   }
			else{
				$i="";
			}	 
		} 
		if($i=="<ORGANISATION>") {
			if(org==0){
			  org=1;
			}
			orgName="";
		}
		if($i=="</ORGANISATION>"){
		   if(org==1){
			org=0;
			print orgName" "$i >> $1".txt";
			orgName="";
		   }
			else{
				$i="";
			}
		}
		if($i=="<CARDINAL>") {
			if(cardinal==0){
			  cardinal=1;
			}
			cardName="";
		}
		if($i=="</CARDINAL>"){
		   if(cardinal==1){
			cardinal=0;
			print cardName" "$i >> $1".txt";
			cardName="";
		   }
			else{
				$i="";
			}
		} 
		if(pers==1) persName=persName" "$i;
		if(place==1) placeName=placeName" "$i;
		if(date==1) dateName=dateName" "$i;
		if(org==1) orgName=orgName" "$i;
		if(cardinal==1) cardName=cardName" "$i;

	}

	if(pers==1) print persName" </PER>" >> $1".txt";
	if(place==1) print placeName" </LOCATION>" >> $1".txt";
	if(date==1) print dateName" </DATE>" >> $1".txt";
	if(org==1) print orgName" </ORGANISATION>" >> $1".txt";
	if(cardinal==1) print cardName" </CARDINAL>" >> $1."txt";

	fflush($1".txt")
        close($1".txt")
}' 
