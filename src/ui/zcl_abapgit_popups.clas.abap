CLASS zcl_abapgit_popups DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_abapgit_ui_factory .

  PUBLIC SECTION.

    INTERFACES zif_abapgit_popups .

    TYPES:
      BEGIN OF ty_popup_position,
        start_column LIKE  sy-cucol,
        start_row    LIKE  sy-curow,
        end_column   LIKE  sy-cucol,
        end_row      LIKE  sy-curow,
      END OF ty_popup_position.

    CLASS-METHODS center
      IMPORTING
        !iv_width          TYPE i
        !iv_height         TYPE i
      RETURNING
        VALUE(rs_position) TYPE ty_popup_position.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_default_column TYPE abap_componentdescr-name VALUE `DEFAULT_COLUMN` ##NO_TEXT.

    TYPES:
      ty_lt_fields TYPE STANDARD TABLE OF sval WITH DEFAULT KEY .

    CONSTANTS c_fieldname_selected TYPE abap_componentdescr-name VALUE `SELECTED` ##NO_TEXT.
    CONSTANTS c_answer_cancel      TYPE c LENGTH 1 VALUE 'A' ##NO_TEXT.

    DATA mo_select_list_popup TYPE REF TO cl_salv_table .
    DATA mr_table TYPE REF TO data .
    DATA mv_cancel TYPE abap_bool VALUE abap_false.
    DATA mo_table_descr TYPE REF TO cl_abap_tabledescr .
    DATA ms_position TYPE ty_popup_position.

    METHODS add_field
      IMPORTING
        !iv_tabname    TYPE sval-tabname
        !iv_fieldname  TYPE sval-fieldname
        !iv_fieldtext  TYPE sval-fieldtext
        !iv_value      TYPE clike DEFAULT ''
        !iv_field_attr TYPE sval-field_attr DEFAULT ''
        !iv_obligatory TYPE spo_obl OPTIONAL
      CHANGING
        !ct_fields     TYPE zif_abapgit_popups=>ty_sval_tt .
    METHODS create_new_table
      IMPORTING
        !it_list TYPE STANDARD TABLE .
    METHODS get_selected_rows
      EXPORTING
        !et_list TYPE INDEX TABLE .
    METHODS on_select_list_link_click
        FOR EVENT link_click OF cl_salv_events_table
      IMPORTING
        !row
        !column .
    METHODS on_select_list_function_click
        FOR EVENT added_function OF cl_salv_events_table
      IMPORTING
        !e_salv_function .
    METHODS on_double_click
        FOR EVENT double_click OF cl_salv_events_table
      IMPORTING
        !row
        !column .
    METHODS _popup_3_get_values
      IMPORTING
        !iv_popup_title    TYPE string
        !iv_no_value_check TYPE abap_bool DEFAULT abap_false
      EXPORTING
        !ev_value_1        TYPE spo_value
        !ev_value_2        TYPE spo_value
        !ev_value_3        TYPE spo_value
      CHANGING
        !ct_fields         TYPE ty_lt_fields
      RAISING
        zcx_abapgit_exception .
ENDCLASS.



CLASS zcl_abapgit_popups IMPLEMENTATION.


  METHOD add_field.

    FIELD-SYMBOLS: <ls_field> LIKE LINE OF ct_fields.

    APPEND INITIAL LINE TO ct_fields ASSIGNING <ls_field>.
    <ls_field>-tabname    = iv_tabname.
    <ls_field>-fieldname  = iv_fieldname.
    <ls_field>-fieldtext  = iv_fieldtext.
    <ls_field>-value      = iv_value.
    <ls_field>-field_attr = iv_field_attr.
    <ls_field>-field_obl  = iv_obligatory.

  ENDMETHOD.


  METHOD center.

    CONSTANTS:
      lc_min_size TYPE i VALUE 10,
      lc_min_pos  TYPE i VALUE 5.

    " Magic math to approximate starting position of popup
    IF sy-scols > lc_min_size AND iv_width > 0 AND sy-scols > iv_width.
      rs_position-start_column = nmax(
        val1 = ( sy-scols - iv_width ) / 2
        val2 = lc_min_pos ).
    ELSE.
      rs_position-start_column = lc_min_pos.
    ENDIF.

    IF sy-srows > lc_min_size AND iv_height > 0 AND sy-srows > iv_height.
      rs_position-start_row = nmax(
        val1 = ( sy-srows - iv_height ) / 2 - 1
        val2 = lc_min_pos ).
    ELSE.
      rs_position-start_row = lc_min_pos.
    ENDIF.

    rs_position-end_column = rs_position-start_column + iv_width.
    rs_position-end_row = rs_position-start_row + iv_height.

  ENDMETHOD.


  METHOD create_new_table.

    " create and populate a table on the fly derived from
    " it_data with a select column

    DATA: lr_struct        TYPE REF TO data,
          lt_components    TYPE cl_abap_structdescr=>component_table,
          lo_data_descr    TYPE REF TO cl_abap_datadescr,
          lo_elem_descr    TYPE REF TO cl_abap_elemdescr,
          lo_struct_descr  TYPE REF TO cl_abap_structdescr,
          lo_struct_descr2 TYPE REF TO cl_abap_structdescr.

    FIELD-SYMBOLS: <lt_table>     TYPE STANDARD TABLE,
                   <ls_component> TYPE abap_componentdescr,
                   <lg_line>      TYPE data,
                   <lg_data>      TYPE any,
                   <lg_value>     TYPE any.

    mo_table_descr ?= cl_abap_tabledescr=>describe_by_data( it_list ).
    lo_data_descr = mo_table_descr->get_table_line_type( ).

    CASE lo_data_descr->kind.
      WHEN cl_abap_elemdescr=>kind_elem.
        lo_elem_descr ?= mo_table_descr->get_table_line_type( ).
        INSERT INITIAL LINE INTO lt_components ASSIGNING <ls_component> INDEX 1.
        <ls_component>-name = c_default_column.
        <ls_component>-type = lo_elem_descr.

      WHEN cl_abap_elemdescr=>kind_struct.
        lo_struct_descr ?= mo_table_descr->get_table_line_type( ).
        lt_components = lo_struct_descr->get_components( ).

    ENDCASE.

    IF lt_components IS INITIAL.
      RETURN.
    ENDIF.

    INSERT INITIAL LINE INTO lt_components ASSIGNING <ls_component> INDEX 1.
    <ls_component>-name = c_fieldname_selected.
    <ls_component>-type ?= cl_abap_datadescr=>describe_by_name( 'FLAG' ).

    lo_struct_descr2 = cl_abap_structdescr=>create( lt_components ).
    mo_table_descr = cl_abap_tabledescr=>create( lo_struct_descr2 ).

    CREATE DATA mr_table TYPE HANDLE mo_table_descr.
    ASSIGN mr_table->* TO <lt_table>.
    ASSERT sy-subrc = 0.

    CREATE DATA lr_struct TYPE HANDLE lo_struct_descr2.
    ASSIGN lr_struct->* TO <lg_line>.
    ASSERT sy-subrc = 0.

    LOOP AT it_list ASSIGNING <lg_data>.
      CLEAR <lg_line>.
      CASE lo_data_descr->kind.
        WHEN cl_abap_elemdescr=>kind_elem.
          ASSIGN COMPONENT c_default_column OF STRUCTURE <lg_data> TO <lg_value>.
          ASSERT <lg_value> IS ASSIGNED.
          <lg_line> = <lg_value>.

        WHEN OTHERS.
          MOVE-CORRESPONDING <lg_data> TO <lg_line>.

      ENDCASE.
      INSERT <lg_line> INTO TABLE <lt_table>.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_selected_rows.

    DATA: lv_condition TYPE string,
          lr_exporting TYPE REF TO data.

    FIELD-SYMBOLS: <lg_exporting>    TYPE any,
                   <lt_table>        TYPE STANDARD TABLE,
                   <lg_line>         TYPE any,
                   <lg_value>        TYPE any,
                   <lv_selected>     TYPE abap_bool,
                   <lv_selected_row> TYPE LINE OF salv_t_row.

    DATA: lo_data_descr    TYPE REF TO cl_abap_datadescr,
          lo_selections    TYPE REF TO cl_salv_selections,
          lt_selected_rows TYPE salv_t_row.

    ASSIGN mr_table->* TO <lt_table>.
    ASSERT sy-subrc = 0.

    lo_selections = mo_select_list_popup->get_selections( ).

    IF lo_selections->get_selection_mode( ) = if_salv_c_selection_mode=>single.

      lt_selected_rows = lo_selections->get_selected_rows( ).

      LOOP AT lt_selected_rows ASSIGNING <lv_selected_row>.

        READ TABLE <lt_table>
          ASSIGNING <lg_line>
          INDEX <lv_selected_row>.
        CHECK <lg_line> IS ASSIGNED.

        ASSIGN COMPONENT c_fieldname_selected
           OF STRUCTURE <lg_line>
           TO <lv_selected>.
        CHECK <lv_selected> IS ASSIGNED.

        <lv_selected> = abap_true.

      ENDLOOP.

    ENDIF.

    lv_condition = |{ c_fieldname_selected } = ABAP_TRUE|.

    CREATE DATA lr_exporting LIKE LINE OF et_list.
    ASSIGN lr_exporting->* TO <lg_exporting>.

    mo_table_descr ?= cl_abap_tabledescr=>describe_by_data( et_list ).
    lo_data_descr = mo_table_descr->get_table_line_type( ).

    LOOP AT <lt_table> ASSIGNING <lg_line> WHERE (lv_condition).
      CLEAR <lg_exporting>.

      CASE lo_data_descr->kind.
        WHEN cl_abap_elemdescr=>kind_elem.
          ASSIGN COMPONENT c_default_column OF STRUCTURE <lg_line> TO <lg_value>.
          ASSERT <lg_value> IS ASSIGNED.
          <lg_exporting> = <lg_value>.

        WHEN OTHERS.
          MOVE-CORRESPONDING <lg_line> TO <lg_exporting>.

      ENDCASE.
      APPEND <lg_exporting> TO et_list.
    ENDLOOP.

  ENDMETHOD.


  METHOD on_double_click.

    DATA: lo_selections    TYPE REF TO cl_salv_selections.

    lo_selections = mo_select_list_popup->get_selections( ).

    IF lo_selections->get_selection_mode( ) = if_salv_c_selection_mode=>single.
      mo_select_list_popup->close_screen( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_select_list_function_click.

    FIELD-SYMBOLS: <lt_table>    TYPE STANDARD TABLE,
                   <lg_line>     TYPE any,
                   <lv_selected> TYPE abap_bool.

    ASSIGN mr_table->* TO <lt_table>.
    ASSERT sy-subrc = 0.

    CASE e_salv_function.
      WHEN 'O.K.'.
        mv_cancel = abap_false.
        mo_select_list_popup->close_screen( ).

      WHEN 'ABR'.
        "Canceled: clear list to overwrite nothing
        CLEAR <lt_table>.
        mv_cancel = abap_true.
        mo_select_list_popup->close_screen( ).

      WHEN 'SALL'.
        LOOP AT <lt_table> ASSIGNING <lg_line>.

          ASSIGN COMPONENT c_fieldname_selected
                 OF STRUCTURE <lg_line>
                 TO <lv_selected>.
          ASSERT sy-subrc = 0.

          <lv_selected> = abap_true.

        ENDLOOP.

        mo_select_list_popup->refresh( ).

      WHEN 'DSEL'.
        LOOP AT <lt_table> ASSIGNING <lg_line>.

          ASSIGN COMPONENT c_fieldname_selected
                 OF STRUCTURE <lg_line>
                 TO <lv_selected>.
          ASSERT sy-subrc = 0.

          <lv_selected> = abap_false.

        ENDLOOP.

        mo_select_list_popup->refresh( ).

      WHEN OTHERS.
        CLEAR <lt_table>.
        mo_select_list_popup->close_screen( ).
    ENDCASE.

  ENDMETHOD.


  METHOD on_select_list_link_click.

    FIELD-SYMBOLS: <lt_table>    TYPE STANDARD TABLE,
                   <lg_line>     TYPE any,
                   <lv_selected> TYPE abap_bool.

    ASSIGN mr_table->* TO <lt_table>.
    ASSERT sy-subrc = 0.

    READ TABLE <lt_table> ASSIGNING <lg_line> INDEX row.
    IF sy-subrc = 0.

      ASSIGN COMPONENT c_fieldname_selected
             OF STRUCTURE <lg_line>
             TO <lv_selected>.
      ASSERT sy-subrc = 0.

      IF <lv_selected> = abap_true.
        <lv_selected> = abap_false.
      ELSE.
        <lv_selected> = abap_true.
      ENDIF.

    ENDIF.

    mo_select_list_popup->refresh( ).

  ENDMETHOD.


  METHOD zif_abapgit_popups~branch_list_popup.

    DATA: lo_branches    TYPE REF TO zcl_abapgit_git_branch_list,
          lt_branches    TYPE zif_abapgit_definitions=>ty_git_branch_list_tt,
          lv_answer      TYPE c LENGTH 1,
          lv_default     TYPE i,
          lv_head_suffix TYPE string,
          lv_head_symref TYPE string,
          lv_text        TYPE string,
          lt_selection   TYPE TABLE OF spopli.

    FIELD-SYMBOLS: <ls_sel>    LIKE LINE OF lt_selection,
                   <ls_branch> LIKE LINE OF lt_branches.


    lo_branches    = zcl_abapgit_git_transport=>branches( iv_url ).
    lt_branches    = lo_branches->get_branches_only( ).
    lv_head_suffix = | ({ zif_abapgit_definitions=>c_head_name })|.
    lv_head_symref = lo_branches->get_head_symref( ).

    IF iv_hide_branch IS NOT INITIAL.
      DELETE lt_branches WHERE name = iv_hide_branch.
    ENDIF.

    IF iv_hide_head IS NOT INITIAL.
      DELETE lt_branches WHERE name    = zif_abapgit_definitions=>c_head_name
                            OR is_head = abap_true.
    ENDIF.

    IF lt_branches IS INITIAL.
      IF iv_hide_head IS NOT INITIAL.
        lv_text = 'main'.
      ENDIF.
      IF iv_hide_branch IS NOT INITIAL AND iv_hide_branch <> zif_abapgit_definitions=>c_git_branch-main.
        IF lv_text IS INITIAL.
          lv_text = iv_hide_branch && ' is'.
        ELSE.
          CONCATENATE lv_text 'and' iv_hide_branch 'are' INTO lv_text SEPARATED BY space.
        ENDIF.
      ELSE.
        lv_text = lv_text && ' is'.
      ENDIF.
      IF lv_text IS NOT INITIAL.
        zcx_abapgit_exception=>raise( 'No branches available to select (' && lv_text && ' hidden)' ).
      ELSE.
        zcx_abapgit_exception=>raise( 'No branches are available to select' ).
      ENDIF.
    ENDIF.

    LOOP AT lt_branches ASSIGNING <ls_branch>.

      CHECK <ls_branch>-name IS NOT INITIAL. " To ensure some below ifs

      IF <ls_branch>-is_head = abap_true.

        IF <ls_branch>-name = zif_abapgit_definitions=>c_head_name. " HEAD
          IF <ls_branch>-name <> lv_head_symref AND lv_head_symref IS NOT INITIAL.
            " HEAD but other HEAD symref exists - ignore
            CONTINUE.
          ELSE.
            INSERT INITIAL LINE INTO lt_selection INDEX 1 ASSIGNING <ls_sel>.
            <ls_sel>-varoption = <ls_branch>-name.
          ENDIF.
        ELSE.
          INSERT INITIAL LINE INTO lt_selection INDEX 1 ASSIGNING <ls_sel>.
          <ls_sel>-varoption = <ls_branch>-display_name && lv_head_suffix.
        ENDIF.

        IF lv_default > 0. " Shift down default if set
          lv_default = lv_default + 1.
        ENDIF.
      ELSE.
        APPEND INITIAL LINE TO lt_selection ASSIGNING <ls_sel>.
        <ls_sel>-varoption = <ls_branch>-display_name.
      ENDIF.

      IF <ls_branch>-name = iv_default_branch.
        IF <ls_branch>-is_head = abap_true.
          lv_default = 1.
        ELSE.
          lv_default = sy-tabix.
        ENDIF.
      ENDIF.

    ENDLOOP.

    IF iv_show_new_option = abap_true.
      APPEND INITIAL LINE TO lt_selection ASSIGNING <ls_sel>.
      <ls_sel>-varoption = zif_abapgit_popups=>c_new_branch_label.
    ENDIF.

    ms_position = center(
      iv_width  = 30
      iv_height = lines( lt_selection ) ).

    CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
      EXPORTING
        titel      = 'Select Branch'
        textline1  = 'Select a branch'
        start_col  = ms_position-start_column
        start_row  = ms_position-start_row
        cursorline = lv_default
      IMPORTING
        answer     = lv_answer
      TABLES
        t_spopli   = lt_selection
      EXCEPTIONS
        OTHERS     = 1.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'Error from POPUP_TO_DECIDE_LIST' ).
    ENDIF.

    IF lv_answer = c_answer_cancel.
      RETURN.
    ENDIF.

    READ TABLE lt_selection ASSIGNING <ls_sel> WITH KEY selflag = abap_true.
    ASSERT sy-subrc = 0.

    IF iv_show_new_option = abap_true AND <ls_sel>-varoption = zif_abapgit_popups=>c_new_branch_label.
      rs_branch-name = zif_abapgit_popups=>c_new_branch_label.
    ELSE.
      REPLACE FIRST OCCURRENCE OF lv_head_suffix IN <ls_sel>-varoption WITH ''.
      READ TABLE lt_branches WITH KEY display_name = <ls_sel>-varoption ASSIGNING <ls_branch>.
      IF sy-subrc <> 0.
* branch name longer than 65 characters
        LOOP AT lt_branches ASSIGNING <ls_branch> WHERE display_name CS <ls_sel>-varoption.
          EXIT. " current loop
        ENDLOOP.
      ENDIF.
      ASSERT <ls_branch> IS ASSIGNED.
      rs_branch = lo_branches->find_by_name( <ls_branch>-name ).
      lv_text = |Branch switched from { zcl_abapgit_git_branch_list=>get_display_name( iv_default_branch ) } to {
        zcl_abapgit_git_branch_list=>get_display_name( rs_branch-name ) } |.
      MESSAGE lv_text TYPE 'S'.
    ENDIF.

  ENDMETHOD.


  METHOD zif_abapgit_popups~branch_popup_callback.

    DATA: lv_url          TYPE string,
          ls_package_data TYPE scompkdtln,
          ls_branch       TYPE zif_abapgit_definitions=>ty_git_branch,
          lv_create       TYPE abap_bool,
          lv_text         TYPE string.

    FIELD-SYMBOLS: <ls_furl>     LIKE LINE OF ct_fields,
                   <ls_fbranch>  LIKE LINE OF ct_fields,
                   <ls_fpackage> LIKE LINE OF ct_fields.

    CLEAR cs_error.

    IF iv_code = 'COD1'.
      cv_show_popup = abap_true.

      READ TABLE ct_fields ASSIGNING <ls_furl> WITH KEY tabname = 'ABAPTXT255'.
      IF sy-subrc <> 0 OR <ls_furl>-value IS INITIAL.
        MESSAGE 'Fill URL' TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
      lv_url = <ls_furl>-value.

      ls_branch = zif_abapgit_popups~branch_list_popup( lv_url ).
      IF ls_branch IS INITIAL.
        RETURN.
      ENDIF.

      READ TABLE ct_fields ASSIGNING <ls_fbranch> WITH KEY tabname = 'TEXTL'.
      ASSERT sy-subrc = 0.
      <ls_fbranch>-value = ls_branch-name.

    ELSEIF iv_code = 'COD2'.
      cv_show_popup = abap_true.

      READ TABLE ct_fields ASSIGNING <ls_fpackage> WITH KEY fieldname = 'DEVCLASS'.
      ASSERT sy-subrc = 0.
      ls_package_data-devclass = <ls_fpackage>-value.

      IF zcl_abapgit_factory=>get_sap_package( ls_package_data-devclass )->exists( ) = abap_true.
        lv_text = |Package { ls_package_data-devclass } already exists|.
        MESSAGE lv_text TYPE 'I' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.

      zif_abapgit_popups~popup_to_create_package(
        IMPORTING
          es_package_data = ls_package_data
          ev_create       = lv_create ).
      IF lv_create = abap_false.
        RETURN.
      ENDIF.

      zcl_abapgit_factory=>get_sap_package( ls_package_data-devclass )->create( ls_package_data ).
      COMMIT WORK.

      <ls_fpackage>-value = ls_package_data-devclass.
    ENDIF.

  ENDMETHOD.


  METHOD zif_abapgit_popups~choose_pr_popup.

    DATA lv_answer    TYPE c LENGTH 1.
    DATA lt_selection TYPE TABLE OF spopli.
    FIELD-SYMBOLS <ls_sel>  LIKE LINE OF lt_selection.
    FIELD-SYMBOLS <ls_pull> LIKE LINE OF it_pulls.

    IF lines( it_pulls ) = 0.
      zcx_abapgit_exception=>raise( 'No pull requests to select from' ).
    ENDIF.

    LOOP AT it_pulls ASSIGNING <ls_pull>.
      APPEND INITIAL LINE TO lt_selection ASSIGNING <ls_sel>.
      <ls_sel>-varoption = |{ <ls_pull>-number } - { <ls_pull>-title } @{ <ls_pull>-user }|.
    ENDLOOP.

    ms_position = center(
      iv_width  = 74
      iv_height = lines( lt_selection ) ).

    CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
      EXPORTING
        textline1 = 'Select pull request'
        titel     = 'Select pull request'
        start_col = ms_position-start_column
        start_row = ms_position-start_row
      IMPORTING
        answer    = lv_answer
      TABLES
        t_spopli  = lt_selection
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'Error from POPUP_TO_DECIDE_LIST' ).
    ENDIF.

    IF lv_answer = c_answer_cancel.
      RETURN.
    ENDIF.

    READ TABLE lt_selection ASSIGNING <ls_sel> WITH KEY selflag = abap_true.
    ASSERT sy-subrc = 0.

    READ TABLE it_pulls INTO rs_pull INDEX sy-tabix.
    ASSERT sy-subrc = 0.

  ENDMETHOD.


  METHOD zif_abapgit_popups~create_branch_popup.

    DATA: lt_fields TYPE TABLE OF sval.
    DATA: lv_name   TYPE spo_value.

    CLEAR: ev_name, ev_cancel.

    add_field( EXPORTING iv_tabname   = 'TEXTL'
                         iv_fieldname = 'LINE'
                         iv_fieldtext = 'Name'
                         iv_value     = 'new-branch-name'
               CHANGING  ct_fields    = lt_fields ).

    TRY.

        _popup_3_get_values(
          EXPORTING iv_popup_title = |Create branch from {
            zcl_abapgit_git_branch_list=>get_display_name( iv_source_branch_name ) }|
          IMPORTING ev_value_1     = lv_name
          CHANGING  ct_fields      = lt_fields ).

        ev_name = zcl_abapgit_git_branch_list=>complete_heads_branch_name(
              zcl_abapgit_git_branch_list=>normalize_branch_name( lv_name ) ).

      CATCH zcx_abapgit_cancel.
        ev_cancel = abap_true.
    ENDTRY.

  ENDMETHOD.


  METHOD zif_abapgit_popups~popup_folder_logic.

    DATA: lt_fields       TYPE TABLE OF sval.
    DATA: lv_folder_logic TYPE spo_value.

    CLEAR: rv_folder_logic.

    add_field( EXPORTING iv_tabname   = 'TDEVC'
                         iv_fieldname = 'INTSYS'
                         iv_fieldtext = 'Folder logic'
                         iv_value     = 'PREFIX'
               CHANGING  ct_fields    = lt_fields ).

    TRY.

        _popup_3_get_values( EXPORTING iv_popup_title    = 'Export package'
                                       iv_no_value_check = abap_true
                             IMPORTING ev_value_1        = lv_folder_logic
                             CHANGING  ct_fields         = lt_fields ).

        rv_folder_logic = to_upper( lv_folder_logic ).

      CATCH zcx_abapgit_cancel.
    ENDTRY.

  ENDMETHOD.


  METHOD zif_abapgit_popups~popup_search_help.

    DATA lt_ret TYPE TABLE OF ddshretval.
    DATA ls_ret LIKE LINE OF lt_ret.
    DATA lv_tabname TYPE dfies-tabname.
    DATA lv_fieldname TYPE dfies-fieldname.

    SPLIT iv_tab_field AT '-' INTO lv_tabname lv_fieldname.
    lv_tabname = to_upper( lv_tabname ).
    lv_fieldname = to_upper( lv_fieldname ).

    CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
      EXPORTING
        tabname    = lv_tabname
        fieldname  = lv_fieldname
      TABLES
        return_tab = lt_ret
      EXCEPTIONS
        OTHERS     = 5.

    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |F4IF_FIELD_VALUE_REQUEST error [{ iv_tab_field }]| ).
    ENDIF.

    IF lines( lt_ret ) > 0.
      READ TABLE lt_ret WITH KEY fieldname = lv_fieldname INTO ls_ret.
      IF sy-subrc = 0.
        rv_value = ls_ret-fieldval.
      ELSE.
        READ TABLE lt_ret INDEX 1 INTO ls_ret.
        ASSERT sy-subrc = 0.
        rv_value = ls_ret-fieldval.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD zif_abapgit_popups~popup_select_tr_requests.
    DATA ls_r_trkorr TYPE LINE OF zif_abapgit_definitions=>ty_trrngtrkor_tt.
    DATA lr_request TYPE REF TO trwbo_request_header.
    DATA lt_request TYPE trwbo_request_headers.

    ms_position = center(
      iv_width  = 120
      iv_height = 10 ).

    CALL FUNCTION 'TRINT_SELECT_REQUESTS'
      EXPORTING
        iv_username_pattern    = iv_username_pattern
        is_selection           = is_selection
        iv_complete_projects   = abap_false
        is_popup               = ms_position
        iv_via_selscreen       = 'X'
        iv_title               = iv_title
      IMPORTING
        et_requests            = lt_request
      EXCEPTIONS
        action_aborted_by_user = 1
        OTHERS                 = 2.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'Selection canceled' ).
    ENDIF.

    IF lt_request IS INITIAL.
      zcx_abapgit_exception=>raise( 'No Request Found' ).
    ENDIF.

    LOOP AT lt_request REFERENCE INTO lr_request.
      ls_r_trkorr-sign = 'I'.
      ls_r_trkorr-option = 'EQ'.
      ls_r_trkorr-low = lr_request->trkorr.
      INSERT ls_r_trkorr INTO TABLE rt_r_trkorr.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_abapgit_popups~popup_select_wb_tc_tr_and_tsk.
    DATA ls_selection  TYPE trwbo_selection.
    DATA lv_title TYPE trwbo_title.

    ls_selection-trkorrpattern = space.
    ls_selection-connect_req_task_conditions = 'X'.
    ls_selection-reqfunctions = 'KTRXS'.
    ls_selection-reqstatus = 'RNODL'.
    ls_selection-taskstatus = 'RNODL'.
    CONDENSE ls_selection-reqfunctions NO-GAPS.
    ls_selection-taskfunctions = 'QRSX'.
    CONCATENATE sy-sysid '*' INTO ls_selection-trkorrpattern.

    lv_title = 'Select Transports / Tasks'.

    rt_r_trkorr = zif_abapgit_popups~popup_select_tr_requests(
      is_selection        = ls_selection
      iv_title            = lv_title
      iv_username_pattern = '*' ).
  ENDMETHOD.


  METHOD zif_abapgit_popups~popup_to_confirm.

    ms_position = center(
      iv_width  = 65
      iv_height = 5 ).

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = iv_titlebar
        text_question         = iv_text_question
        text_button_1         = iv_text_button_1
        icon_button_1         = iv_icon_button_1
        text_button_2         = iv_text_button_2
        icon_button_2         = iv_icon_button_2
        default_button        = iv_default_button
        display_cancel_button = iv_display_cancel_button
        start_column          = ms_position-start_column
        start_row             = ms_position-start_row
      IMPORTING
        answer                = rv_answer
      EXCEPTIONS
        text_not_found        = 1
        OTHERS                = 2.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'error from POPUP_TO_CONFIRM' ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_abapgit_popups~popup_to_create_package.
    CALL FUNCTION 'FUNCTION_EXISTS'
      EXPORTING
        funcname           = 'PB_POPUP_PACKAGE_CREATE'
      EXCEPTIONS
        function_not_exist = 1
        OTHERS             = 2.
    IF sy-subrc = 1.
* looks like the function module used does not exist on all
* versions since 702, so show an error
      zcx_abapgit_exception=>raise( 'Your system does not support automatic creation of packages.' &&
        'Please, create the package manually.' ).
    ENDIF.

    CALL FUNCTION 'PB_POPUP_PACKAGE_CREATE'
      CHANGING
        p_object_data    = es_package_data
      EXCEPTIONS
        action_cancelled = 1.
    ev_create = boolc( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD zif_abapgit_popups~popup_to_create_transp_branch.
    DATA: lt_fields             TYPE TABLE OF sval,
          lv_transports_as_text TYPE string,
          lv_desc_as_text       TYPE string,
          ls_transport_header   LIKE LINE OF it_transport_headers.
    DATA: lv_branch_name        TYPE spo_value.
    DATA: lv_commit_text        TYPE spo_value.

    CLEAR: rs_transport_branch-branch_name, rs_transport_branch-commit_text.

    " If we only have one transport selected set branch name to Transport
    " name and commit description to transport description.
    IF lines( it_transport_headers ) = 1.
      READ TABLE it_transport_headers INDEX 1 INTO ls_transport_header.
      lv_transports_as_text = ls_transport_header-trkorr.
      SELECT SINGLE as4text FROM e07t INTO lv_desc_as_text  WHERE
        trkorr = ls_transport_header-trkorr AND
        langu = sy-langu.
    ELSE.   " Else set branch name and commit message to 'Transport(s)_TRXXXXXX_TRXXXXX'
      lv_transports_as_text = 'Transport(s)'.
      LOOP AT it_transport_headers INTO ls_transport_header.
        CONCATENATE lv_transports_as_text '_' ls_transport_header-trkorr INTO lv_transports_as_text.
      ENDLOOP.
      lv_desc_as_text = lv_transports_as_text.

    ENDIF.
    add_field( EXPORTING iv_tabname   = 'TEXTL'
                         iv_fieldname = 'LINE'
                         iv_fieldtext = 'Branch name'
                         iv_value     = lv_transports_as_text
               CHANGING  ct_fields    = lt_fields ).

    add_field( EXPORTING iv_tabname   = 'ABAPTXT255'
                         iv_fieldname = 'LINE'
                         iv_fieldtext = 'Commit text'
                         iv_value     = lv_desc_as_text
               CHANGING  ct_fields    = lt_fields ).

    _popup_3_get_values( EXPORTING iv_popup_title = 'Transport to new Branch'
                         IMPORTING ev_value_1     = lv_branch_name
                                   ev_value_2     = lv_commit_text
                         CHANGING  ct_fields      = lt_fields ).

    rs_transport_branch-branch_name = lv_branch_name.
    rs_transport_branch-commit_text = lv_commit_text.

  ENDMETHOD.


  METHOD zif_abapgit_popups~popup_to_select_from_list.

    DATA: lv_pfstatus     TYPE sypfkey,
          lo_events       TYPE REF TO cl_salv_events_table,
          lo_columns      TYPE REF TO cl_salv_columns_table,
          lt_columns      TYPE salv_t_column_ref,
          ls_column       TYPE salv_s_column_ref,
          lo_column       TYPE REF TO cl_salv_column_list,
          lo_table_header TYPE REF TO cl_salv_form_text.

    FIELD-SYMBOLS: <lt_table>             TYPE STANDARD TABLE,
                   <ls_column_to_display> TYPE zif_abapgit_definitions=>ty_alv_column.

    CLEAR: et_list.

    create_new_table( it_list ).

    ASSIGN mr_table->* TO <lt_table>.
    ASSERT sy-subrc = 0.

    ms_position = center(
      iv_width  = iv_end_column - iv_start_column
      iv_height = iv_end_line - iv_start_line ).

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = mo_select_list_popup
                                CHANGING  t_table      = <lt_table> ).

        CASE iv_selection_mode.
          WHEN if_salv_c_selection_mode=>single.
            lv_pfstatus = '110'.

          WHEN OTHERS.
            lv_pfstatus = '102'.

        ENDCASE.

        mo_select_list_popup->set_screen_status( pfstatus = lv_pfstatus
                                                 report   = 'SAPMSVIM' ).

        mo_select_list_popup->set_screen_popup( start_column = ms_position-start_column
                                                end_column   = ms_position-end_column
                                                start_line   = ms_position-start_row
                                                end_line     = ms_position-end_row ).

        lo_events = mo_select_list_popup->get_event( ).

        SET HANDLER on_select_list_link_click FOR lo_events.
        SET HANDLER on_select_list_function_click FOR lo_events.
        SET HANDLER on_double_click FOR lo_events.

        IF iv_title CN ' _0'.
          mo_select_list_popup->get_display_settings( )->set_list_header( iv_title ).
        ENDIF.

        IF iv_header_text CN ' _0'.
          CREATE OBJECT lo_table_header
            EXPORTING
              text = iv_header_text.
          mo_select_list_popup->set_top_of_list( lo_table_header ).
        ENDIF.

        mo_select_list_popup->get_display_settings( )->set_striped_pattern( iv_striped_pattern ).
        mo_select_list_popup->get_selections( )->set_selection_mode( iv_selection_mode ).

        lo_columns = mo_select_list_popup->get_columns( ).
        lt_columns = lo_columns->get( ).
        lo_columns->set_optimize( iv_optimize_col_width ).

        LOOP AT lt_columns INTO ls_column.

          lo_column ?= ls_column-r_column.

          IF    iv_selection_mode    = if_salv_c_selection_mode=>multiple
            AND ls_column-columnname = c_fieldname_selected.
            lo_column->set_cell_type( if_salv_c_cell_type=>checkbox_hotspot ).
            lo_column->set_output_length( 20 ).
            lo_column->set_short_text( |{ iv_select_column_text }| ).
            lo_column->set_medium_text( |{ iv_select_column_text }| ).
            lo_column->set_long_text( |{ iv_select_column_text }| ).
            CONTINUE.
          ENDIF.

          READ TABLE it_columns_to_display
            ASSIGNING <ls_column_to_display>
            WITH KEY name = ls_column-columnname.

          CASE sy-subrc.
            WHEN 0.
              IF <ls_column_to_display>-text CN ' _0'.
                lo_column->set_short_text( |{ <ls_column_to_display>-text }| ).
                lo_column->set_medium_text( |{ <ls_column_to_display>-text }| ).
                lo_column->set_long_text( |{ <ls_column_to_display>-text }| ).
              ENDIF.

              IF <ls_column_to_display>-length > 0.
                lo_column->set_output_length( <ls_column_to_display>-length ).
              ENDIF.

              IF <ls_column_to_display>-show_icon = abap_true.
                lo_column->set_icon( abap_true ).
              ENDIF.

            WHEN OTHERS.
              " Hide column
              lo_column->set_technical( abap_true ).

          ENDCASE.

        ENDLOOP.

        mo_select_list_popup->display( ).

      CATCH cx_salv_msg.
        zcx_abapgit_exception=>raise( 'Error from POPUP_TO_SELECT_FROM_LIST' ).
    ENDTRY.

    IF mv_cancel = abap_true.
      mv_cancel = abap_false.
      RAISE EXCEPTION TYPE zcx_abapgit_cancel.
    ENDIF.

    get_selected_rows( IMPORTING et_list = et_list ).

    CLEAR: mo_select_list_popup,
           mr_table,
           mo_table_descr.

  ENDMETHOD.


  METHOD zif_abapgit_popups~popup_to_select_transports.

* todo, method to be renamed, it only returns one transport

    DATA: lv_trkorr TYPE e070-trkorr,
          ls_trkorr LIKE LINE OF rt_trkorr.


    CALL FUNCTION 'TR_F4_REQUESTS'
      IMPORTING
        ev_selected_request = lv_trkorr.

    IF NOT lv_trkorr IS INITIAL.
      ls_trkorr-trkorr = lv_trkorr.
      APPEND ls_trkorr TO rt_trkorr.
    ENDIF.

  ENDMETHOD.


  METHOD zif_abapgit_popups~popup_transport_request.

    DATA: lt_e071    TYPE STANDARD TABLE OF e071,
          lt_e071k   TYPE STANDARD TABLE OF e071k,
          lv_order   TYPE trkorr,
          ls_e070use TYPE e070use.

    " If default transport is set and its type matches, then use it as default for the popup
    ls_e070use = zcl_abapgit_default_transport=>get_instance( )->get( ).

    IF ( ls_e070use-trfunction = is_transport_type-request OR ls_e070use-trfunction IS INITIAL )
      AND iv_use_default_transport = abap_true.
      lv_order = ls_e070use-ordernum.
    ENDIF.

    CALL FUNCTION 'TRINT_ORDER_CHOICE'
      EXPORTING
        wi_order_type          = is_transport_type-request
        wi_task_type           = is_transport_type-task
        wi_order               = lv_order
      IMPORTING
        we_order               = rv_transport
      TABLES
        wt_e071                = lt_e071
        wt_e071k               = lt_e071k
      EXCEPTIONS
        no_correction_selected = 1
        display_mode           = 2
        object_append_error    = 3
        recursive_call         = 4
        wrong_order_type       = 5
        OTHERS                 = 6.

    IF sy-subrc = 1.
      RAISE EXCEPTION TYPE zcx_abapgit_cancel.
    ELSEIF sy-subrc > 1.
      zcx_abapgit_exception=>raise_t100( ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_abapgit_popups~tag_list_popup.

    DATA: lo_branches  TYPE REF TO zcl_abapgit_git_branch_list,
          lt_tags      TYPE zif_abapgit_definitions=>ty_git_branch_list_tt,
          ls_branch    TYPE zif_abapgit_definitions=>ty_git_branch,
          lv_answer    TYPE c LENGTH 1,
          lv_default   TYPE i,
          lv_tag       TYPE string,
          lt_selection TYPE TABLE OF spopli.

    FIELD-SYMBOLS: <ls_sel> LIKE LINE OF lt_selection,
                   <ls_tag> LIKE LINE OF lt_tags.


    lo_branches = zcl_abapgit_git_transport=>branches( iv_url ).
    lt_tags     = lo_branches->get_tags_only( ).

    LOOP AT lt_tags ASSIGNING <ls_tag> WHERE name NP '*^{}'.

      APPEND INITIAL LINE TO lt_selection ASSIGNING <ls_sel>.
      <ls_sel>-varoption = zcl_abapgit_git_tag=>remove_tag_prefix( <ls_tag>-name ).

    ENDLOOP.

    IF lt_selection IS INITIAL.
      zcx_abapgit_exception=>raise( 'No tags are available to select' ).
    ENDIF.

    ms_position = center(
      iv_width  = 30
      iv_height = lines( lt_selection ) ).

    CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
      EXPORTING
        titel      = 'Select Tag'
        textline1  = 'Select a tag'
        start_col  = ms_position-start_column
        start_row  = ms_position-start_row
        cursorline = lv_default
      IMPORTING
        answer     = lv_answer
      TABLES
        t_spopli   = lt_selection
      EXCEPTIONS
        OTHERS     = 1.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'Error from POPUP_TO_DECIDE_LIST' ).
    ENDIF.

    IF lv_answer = c_answer_cancel.
      RETURN.
    ENDIF.

    READ TABLE lt_selection ASSIGNING <ls_sel> WITH KEY selflag = abap_true.
    ASSERT sy-subrc = 0.

    lv_tag = zcl_abapgit_git_tag=>add_tag_prefix( <ls_sel>-varoption ).

    READ TABLE lt_tags WITH KEY name_key COMPONENTS name = lv_tag ASSIGNING <ls_tag>.
    IF sy-subrc <> 0.
      " tag name longer than 65 characters
      LOOP AT lt_tags ASSIGNING <ls_tag> WHERE name CS lv_tag.
        EXIT.
      ENDLOOP.
    ENDIF.
    ASSERT <ls_tag> IS ASSIGNED.

    ls_branch = lo_branches->find_by_name( <ls_tag>-name ).
    MOVE-CORRESPONDING ls_branch TO rs_tag.

  ENDMETHOD.


  METHOD _popup_3_get_values.

    DATA lv_answer TYPE c LENGTH 1.
    FIELD-SYMBOLS: <ls_field> TYPE sval.

    ms_position = center(
      iv_width  = 120
      iv_height = lines( ct_fields ) ).

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        no_value_check = iv_no_value_check
        popup_title    = iv_popup_title
        start_column   = ms_position-start_column
        start_row      = ms_position-start_row
      IMPORTING
        returncode     = lv_answer
      TABLES
        fields         = ct_fields
      EXCEPTIONS
        OTHERS         = 1.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'Error from POPUP_GET_VALUES' ).
    ENDIF.

    IF lv_answer = c_answer_cancel.
      RAISE EXCEPTION TYPE zcx_abapgit_cancel.
    ENDIF.

    IF ev_value_1 IS SUPPLIED.
      READ TABLE ct_fields INDEX 1 ASSIGNING <ls_field>.
      ASSERT sy-subrc = 0.
      ev_value_1 = <ls_field>-value.
    ENDIF.

    IF ev_value_2 IS SUPPLIED.
      READ TABLE ct_fields INDEX 2 ASSIGNING <ls_field>.
      ASSERT sy-subrc = 0.
      ev_value_2 = <ls_field>-value.
    ENDIF.

    IF ev_value_3 IS SUPPLIED.
      READ TABLE ct_fields INDEX 3 ASSIGNING <ls_field>.
      ASSERT sy-subrc = 0.
      ev_value_3 = <ls_field>-value.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
