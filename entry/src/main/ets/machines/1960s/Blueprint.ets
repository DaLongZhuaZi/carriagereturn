import { MachineBlueprint } from '../BlueprintTypes';

/** 1960s 蓝图：值取自 docs/素材分层锚点表.md 的 1960s 实测节。 */
export const BLUEPRINT_1960: MachineBlueprint = {
  leverSizeRatio: 0.12,
  leverAspect: 0.12,
  bracketAspect: 0.71,
  bracketPivotX: 0.498,
  bracketPivotY: 0.358,
  rollerWidthRatio: 0.9528,
  leverPivotY: 0.948,
  bracketRawfile: (): Resource => $rawfile('layers/1960s-electric/lever-pivot-bracket.png'),
};